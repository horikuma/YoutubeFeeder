import Foundation
import Combine

@MainActor
final class FeedCacheCoordinator: ObservableObject {
    @Published private(set) var progress: CacheProgress
    @Published private(set) var maintenanceItems: [ChannelMaintenanceItem] = []
    @Published private(set) var videos: [CachedVideo] = []
    @Published private(set) var refreshProgress: CacheRefreshProgress = .idle
    @Published private(set) var manualRefreshCount: Int = 0
    @Published private(set) var lastManualChannelRefreshID: String?
    @Published private(set) var homeSystemStatus = HomeSystemStatus.empty(keyword: FeedCacheCoordinator.homeSearchKeyword)

    private var channels: [String]
    private let store: FeedCacheStore
    private let feedService: YouTubeFeedService
    private let channelResolver: YouTubeChannelResolver
    private let searchService: YouTubeSearchService
    private let remoteSearchCacheStore: RemoteVideoSearchCacheStore
    private var manualRefreshTask: Task<Void, Never>?
    private var importRefreshTask: Task<Void, Never>?
    private var freshnessInterval: TimeInterval
    private var videoQuery = VideoQuery()
    private var liveUpdateSuspendCount = 0
    private var needsRefreshWhenResumed = false
    private var remoteSearchTasks: [RemoteSearchTaskKey: Task<VideoSearchResult, Never>] = [:]
    private let remoteSearchCacheLifetime: TimeInterval = 12 * 60 * 60

    static let homeSearchKeyword = "ゆっくり実況"

    private var channelSyncService: FeedChannelSyncService {
        FeedChannelSyncService(store: store, feedService: feedService)
    }

    private var remoteSearchService: RemoteVideoSearchService {
        RemoteVideoSearchService(
            searchService: searchService,
            cacheStore: remoteSearchCacheStore,
            cacheLifetime: remoteSearchCacheLifetime
        )
    }

    private var homeSystemStatusService: HomeSystemStatusService {
        HomeSystemStatusService(
            store: store,
            remoteSearchService: remoteSearchService,
            homeSearchKeyword: Self.homeSearchKeyword
        )
    }

    private var channelRegistryMaintenanceService: ChannelRegistryMaintenanceService {
        ChannelRegistryMaintenanceService(
            store: store,
            feedService: feedService,
            channelResolver: channelResolver,
            remoteSearchService: remoteSearchService
        )
    }

    init(
        channels: [String],
        dependencies: FeedCacheDependencies,
        freshnessInterval: TimeInterval? = nil
    ) {
        self.channels = channels
        self.store = dependencies.store
        self.feedService = dependencies.feedService
        self.channelResolver = dependencies.channelResolver
        self.searchService = dependencies.searchService
        self.remoteSearchCacheStore = dependencies.remoteSearchCacheStore
        self.freshnessInterval = freshnessInterval ?? TimeInterval(max(channels.count, 1) * 60)
        let bootstrap = FeedBootstrapStore.load(channels: channels)
        self.progress = bootstrap.progress
        self.maintenanceItems = bootstrap.maintenanceItems
    }

    func bootstrapMaintenance() async {
        let startedAt = Date()
        channels = ChannelRegistryStore.loadAllChannelIDs()
        freshnessInterval = TimeInterval(max(channels.count, 1) * 60)
        _ = await performConsistencyMaintenanceIfNeeded(force: false)
        let bootstrap = FeedBootstrapStore.load(channels: channels)
        progress = bootstrap.progress
        maintenanceItems = bootstrap.maintenanceItems
        await refreshHomeSystemStatus()
        AppConsoleLogger.appLifecycle.notice(
            "bootstrap_coordinator_complete",
            metadata: [
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                "channels": String(channels.count),
                "maintenance_items": String(maintenanceItems.count),
            ]
        )
    }

    func suspendLiveUpdates() {
        liveUpdateSuspendCount += 1
        RuntimeDiagnostics.shared.record(
            "live_updates_suspended",
            detail: "一覧のライブ更新を抑止",
            metadata: ["suspendCount": String(liveUpdateSuspendCount)]
        )
    }

    func resumeLiveUpdates() {
        liveUpdateSuspendCount = max(liveUpdateSuspendCount - 1, 0)
        RuntimeDiagnostics.shared.record(
            "live_updates_resumed",
            detail: "一覧のライブ更新抑止を解除",
            metadata: [
                "suspendCount": String(liveUpdateSuspendCount),
                "needsRefreshWhenResumed": needsRefreshWhenResumed ? "true" : "false"
            ]
        )

        guard liveUpdateSuspendCount == 0, needsRefreshWhenResumed else { return }
        needsRefreshWhenResumed = false
        refreshMaintenanceFromCache()
    }

    func refreshCacheManually() async {
        guard manualRefreshTask == nil else { return }

        manualRefreshTask = Task {
            StartupDiagnostics.shared.mark("manualRefreshStarted")
            manualRefreshCount += 1
            if AppLaunchMode.current.usesMockData {
                await performMockRefresh()
            } else {
                await performManualRefresh()
            }
            StartupDiagnostics.shared.mark("manualRefreshFinished")
        }
        await manualRefreshTask?.value
        manualRefreshTask = nil
    }

    func refreshChannelManually(_ channelID: String) async {
        let normalizedChannelID = channelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedChannelID.isEmpty else {
            RuntimeDiagnostics.shared.record("channel_manual_refresh_ignored", detail: "空の channelID のため更新しない")
            return
        }
        guard manualRefreshTask == nil else {
            RuntimeDiagnostics.shared.record(
                "channel_manual_refresh_ignored",
                detail: "別の手動更新が進行中のため更新しない",
                metadata: ["channelID": normalizedChannelID]
            )
            return
        }

        manualRefreshTask = Task {
            StartupDiagnostics.shared.mark("channelManualRefreshStarted")
            RuntimeDiagnostics.shared.record(
                "channel_manual_refresh_started",
                detail: "チャンネル単独更新を開始",
                metadata: [
                    "channelID": normalizedChannelID,
                    "liveUpdateSuspendCount": String(liveUpdateSuspendCount)
                ]
            )
            lastManualChannelRefreshID = normalizedChannelID
            if AppLaunchMode.current.usesMockData {
                await performMockChannelRefresh(channelID: normalizedChannelID)
            } else {
                await performManualChannelRefresh(channelID: normalizedChannelID)
            }
            StartupDiagnostics.shared.mark("channelManualRefreshFinished")
            let updatedItem = maintenanceItems.first(where: { $0.channelID == normalizedChannelID })
            RuntimeDiagnostics.shared.record(
                "channel_manual_refresh_finished",
                detail: "チャンネル単独更新を完了",
                metadata: [
                    "channelID": normalizedChannelID,
                    "lastError": progress.lastError ?? "",
                    "cachedVideoCount": String(updatedItem?.cachedVideoCount ?? 0),
                    "latestPublishedAt": updatedItem?.latestPublishedAt?.formatted(date: .numeric, time: .standard) ?? ""
                ]
            )
        }
        await manualRefreshTask?.value
        manualRefreshTask = nil
    }

    func refreshMaintenanceFromCache() {
        Task {
            await refreshUI(
                currentChannelID: progress.currentChannelID,
                isRunning: manualRefreshTask != nil,
                lastError: progress.lastError,
                includesVideos: false
            )
        }
    }

    func loadVideosFromCache() {
        Task {
            videos = await store.loadVideos(query: videoQuery)
        }
    }

    func loadChannelBrowseItems(sortDescriptor: ChannelBrowseSortDescriptor = .default) async -> [ChannelBrowseItem] {
        let channelIDs = maintenanceItems.map(\.channelID).isEmpty ? channels : maintenanceItems.map(\.channelID)
        let registeredAtByChannelID = Dictionary(uniqueKeysWithValues: ChannelRegistryStore.loadAllChannels().map { ($0.channelID, $0.addedAt) })
        let items = await store.loadChannelBrowseItems(channelIDs: channelIDs, registeredAtByChannelID: registeredAtByChannelID)
        return FeedOrdering.sortBrowseItems(items, by: sortDescriptor)
    }

    func loadVideosForChannel(_ channelID: String) async -> [CachedVideo] {
        let cachedVideos = await loadCachedVideosForChannel(channelID)
        let remoteVideos = await remoteSearchService.allVideos(channelID: channelID)
        let mergedByID = Dictionary(uniqueKeysWithValues: (cachedVideos + remoteVideos).map { ($0.id, $0) })
        let mergedVideos = mergedByID.values
            .sorted { lhs, rhs in
                switch (lhs.publishedAt, rhs.publishedAt) {
                case let (left?, right?) where left != right:
                    return left > right
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                default:
                    return lhs.fetchedAt > rhs.fetchedAt
                }
            }
            .prefix(200)
            .map { $0 }
        return mergedVideos
    }

    func openChannelVideos(_ context: ChannelVideosRouteContext) async -> [CachedVideo] {
        let channelID = context.channelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !channelID.isEmpty else { return [] }

        let startedAt = Date()
        var mergedVideos = await loadVideosForChannel(channelID)
        guard context.prefersAutomaticRefresh else {
            AppConsoleLogger.appLifecycle.notice(
                "channel_videos_open_complete",
                metadata: [
                    "channelID": channelID,
                    "videos": String(mergedVideos.count),
                    "refreshed": "false",
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                ]
            )
            return mergedVideos
        }

        let shouldRefresh = await shouldAutomaticallyRefreshChannelVideos(context)
        guard shouldRefresh else {
            AppConsoleLogger.appLifecycle.notice(
                "channel_videos_open_complete",
                metadata: [
                    "channelID": channelID,
                    "videos": String(mergedVideos.count),
                    "refreshed": "false",
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                ]
            )
            return mergedVideos
        }

        await refreshChannelManually(channelID)
        mergedVideos = await loadVideosForChannel(channelID)
        AppConsoleLogger.appLifecycle.notice(
            "channel_videos_open_complete",
            metadata: [
                "channelID": channelID,
                "videos": String(mergedVideos.count),
                "refreshed": "true",
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
            ]
        )
        return mergedVideos
    }

    func shouldAutomaticallyRefreshChannelVideos(_ context: ChannelVideosRouteContext) async -> Bool {
        let channelID = context.channelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !channelID.isEmpty else { return false }
        guard context.prefersAutomaticRefresh else { return false }

        let cachedVideos = await loadCachedVideosForChannel(channelID)
        return ChannelVideosAutoRefreshPolicy.shouldRefresh(
            cachedChannelVideos: cachedVideos,
            selectedVideoID: context.selectedVideoID
        )
    }

    func searchVideos(keyword: String, limit: Int = 20) async -> VideoSearchResult {
        let normalizedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let query = VideoQuery(limit: limit, channelID: nil, keyword: normalizedKeyword, sortOrder: .publishedDescending, excludeShorts: true)
        let videos = await store.loadVideos(query: query)
        let totalCount = await store.countVideos(query: VideoQuery(limit: .max, channelID: nil, keyword: normalizedKeyword, sortOrder: .publishedDescending, excludeShorts: true))
        return VideoSearchResult(keyword: normalizedKeyword, videos: videos, totalCount: totalCount, source: .localCache)
    }

    func loadRemoteSearchSnapshot(keyword: String, limit: Int = 100) async -> VideoSearchResult {
        let normalizedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKeyword.isEmpty else {
            return VideoSearchResult(keyword: normalizedKeyword, videos: [], totalCount: 0, source: .remoteCache)
        }

        let logger = AppConsoleLogger.youtubeSearch

        if AppLaunchMode.current.usesMockData {
            if let cached = await remoteSearchService.loadSnapshot(keyword: normalizedKeyword, limit: limit, allowExpired: true) {
                logger.info(
                    "snapshot_hit",
                    metadata: ["keyword": AppConsoleLogger.sanitizedKeyword(normalizedKeyword), "source": cached.source.label, "videos": String(cached.videos.count)]
                )
                return cached
            }
            let local = await searchVideos(keyword: normalizedKeyword, limit: limit)
            logger.info(
                "snapshot_mock_local",
                metadata: ["keyword": AppConsoleLogger.sanitizedKeyword(normalizedKeyword), "videos": String(local.videos.count)]
            )
            let result = VideoSearchResult(
                keyword: normalizedKeyword,
                videos: local.videos,
                totalCount: local.totalCount,
                source: .mockData,
                fetchedAt: .now,
                expiresAt: Date().addingTimeInterval(remoteSearchCacheLifetime)
            )
            return result
        }

        if let cached = await remoteSearchService.loadSnapshot(keyword: normalizedKeyword, limit: limit, allowExpired: true) {
            logger.info(
                "snapshot_hit",
                metadata: ["keyword": AppConsoleLogger.sanitizedKeyword(normalizedKeyword), "source": cached.source.label, "videos": String(cached.videos.count)]
            )
            return cached
        }

        logger.info(
            "snapshot_miss",
            metadata: ["keyword": AppConsoleLogger.sanitizedKeyword(normalizedKeyword), "limit": String(limit)]
        )
        return VideoSearchResult(keyword: normalizedKeyword, videos: [], totalCount: 0, source: .remoteCache)
    }

    func searchRemoteVideos(keyword: String, limit: Int = 100, forceRefresh: Bool = false) async -> VideoSearchResult {
        let normalizedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKeyword.isEmpty else {
            return VideoSearchResult(keyword: normalizedKeyword, videos: [], totalCount: 0, source: .remoteCache)
        }

        let logger = AppConsoleLogger.youtubeSearch
        logger.info(
            "coordinator_search_start",
            metadata: [
                "keyword": AppConsoleLogger.sanitizedKeyword(normalizedKeyword),
                "limit": String(limit),
                "force_refresh": forceRefresh ? "true" : "false",
            ]
        )

        if AppLaunchMode.current.usesMockData {
            if forceRefresh {
                let result = await performManagedRemoteRefresh(
                    keyword: normalizedKeyword,
                    limit: limit,
                    logger: logger,
                    fallbackOnFailure: "snapshot"
                )
                return result
            }
            return await loadRemoteSearchSnapshot(keyword: normalizedKeyword, limit: limit)
        }

        if !forceRefresh {
            return await loadRemoteSearchSnapshot(keyword: normalizedKeyword, limit: limit)
        }

        return await performManagedRemoteRefresh(
            keyword: normalizedKeyword,
            limit: limit,
            logger: logger,
            fallbackOnFailure: "none"
        )
    }

    func addChannel(input: String) async throws -> ChannelRegistrationFeedback {
        let execution = try await channelRegistryMaintenanceService.addChannel(input: input)
        channels = execution.channels
        freshnessInterval = TimeInterval(max(channels.count, 1) * 60)
        _ = await performConsistencyMaintenanceIfNeeded(force: false)
        await refreshUI(currentChannelID: nil, isRunning: false, lastError: progress.lastError, includesVideos: false)
        return execution.feedback
    }

    func removeChannel(_ channelID: String) async -> ChannelRemovalFeedback? {
        guard let execution = await channelRegistryMaintenanceService.removeChannel(
            channelID: channelID,
            maintenanceItems: maintenanceItems,
            videos: videos
        ) else {
            return nil
        }

        channels = execution.channels
        freshnessInterval = TimeInterval(max(channels.count, 1) * 60)
        await refreshUI(currentChannelID: nil, isRunning: false, lastError: progress.lastError)
        return execution.feedback
    }

    func exportChannelRegistry(backend: ChannelRegistryTransferBackend) throws -> ChannelRegistryTransferFeedback {
        try channelRegistryMaintenanceService.exportChannelRegistry(backend: backend)
    }

    func importChannelRegistry(backend: ChannelRegistryTransferBackend) async throws -> ChannelRegistryTransferFeedback {
        let execution = try channelRegistryMaintenanceService.importChannelRegistry(
            backend: backend,
            usesMockData: AppLaunchMode.current.usesMockData
        )
        channels = execution.channels
        freshnessInterval = TimeInterval(max(channels.count, 1) * 60)
        _ = await performConsistencyMaintenanceIfNeeded(force: true)
        await bootstrapMaintenance()

        if !AppLaunchMode.current.usesMockData {
            scheduleImportedChannelRefresh(channelIDs: channels)
        }

        return execution.feedback
    }

    func resetAllSettings() async throws -> LocalStateResetFeedback {
        let feedback = try await channelRegistryMaintenanceService.resetAllSettings()

        channels = []
        freshnessInterval = 60
        manualRefreshCount = 0
        lastManualChannelRefreshID = nil
        refreshProgress = .idle
        progress = CacheProgress(
            totalChannels: 0,
            cachedChannels: 0,
            cachedVideos: 0,
            cachedThumbnails: 0,
            currentChannelID: nil,
            currentChannelNumber: nil,
            lastUpdatedAt: nil,
            isRunning: false,
            lastError: nil
        )
        maintenanceItems = []
        videos = []
        await refreshHomeSystemStatus(
            snapshot: .empty,
            currentProgress: progress
        )

        return feedback
    }

    private func loadCachedVideosForChannel(_ channelID: String) async -> [CachedVideo] {
        await store.loadVideos(
            query: VideoQuery(limit: .max, channelID: channelID, keyword: nil, sortOrder: .publishedDescending, excludeShorts: true)
        )
    }

    private func performManualRefresh() async {
        let snapshot = await store.loadSnapshot()
        let states = Dictionary(uniqueKeysWithValues: snapshot.channels.map { ($0.channelID, $0) })
        let sortedChannels = prioritizedChannelIDs(states: states)
        let totalChannels = sortedChannels.count

        beginManualRefreshProgress(totalChannels: totalChannels)
        let lastError = await runManualRefreshChannels(sortedChannels, states: states)
        finishManualRefreshProgress()
        _ = await performConsistencyMaintenanceIfNeeded(force: false)
        await refreshUI(currentChannelID: nil, isRunning: false, lastError: lastError)
    }

    private func performMockRefresh() async {
        let totalChannels = max(progress.totalChannels, maintenanceItems.count)
        refreshProgress = CacheRefreshProgress(
            isRefreshing: true,
            checkStage: RefreshStageProgress(title: "フィード更新確認", completed: totalChannels, total: totalChannels, activeCalls: 0, callsPerSecond: 3),
            fetchStage: .idle(title: "更新チャンネル取得", callsPerSecond: 0),
            thumbnailStage: .idle(title: "サムネイル取得", callsPerSecond: 0)
        )
        await refreshUI(currentChannelID: nil, isRunning: false, lastError: progress.lastError)
        refreshProgress.isRefreshing = false
        _ = await performConsistencyMaintenanceIfNeeded(force: false)
    }

    private func performMockChannelRefresh(channelID: String) async {
        RuntimeDiagnostics.shared.record(
            "channel_manual_refresh_mock",
            detail: "モック経路でチャンネル更新を処理",
            metadata: ["channelID": channelID]
        )
        refreshProgress = CacheRefreshProgress(
            isRefreshing: true,
            checkStage: RefreshStageProgress(title: "チャンネル更新", completed: 0, total: 1, activeCalls: 1, callsPerSecond: 1),
            fetchStage: .idle(title: "更新チャンネル取得", callsPerSecond: 0),
            thumbnailStage: .idle(title: "サムネイル取得", callsPerSecond: 0)
        )
        await refreshUI(
            currentChannelID: channelID,
            isRunning: false,
            lastError: progress.lastError,
            allowsSuspendedStateUpdate: true
        )
        // Keep the mock refresh visible long enough for UI tests to observe the same spinner affordance as a real refresh.
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        refreshProgress = .idle
    }

    private func performManualChannelRefresh(channelID: String) async {
        let isRegisteredChannel = channels.contains(channelID)
        RuntimeDiagnostics.shared.record(
            "channel_manual_refresh_fetch_started",
            detail: "フィード取得を開始",
            metadata: [
                "channelID": channelID,
                "registered": isRegisteredChannel ? "true" : "false"
            ]
        )
        refreshProgress = CacheRefreshProgress(
            isRefreshing: true,
            checkStage: RefreshStageProgress(title: "チャンネル更新", completed: 0, total: 1, activeCalls: 1, callsPerSecond: 1),
            fetchStage: RefreshStageProgress(title: "更新チャンネル取得", completed: 0, total: 1, activeCalls: 0, callsPerSecond: 1),
            thumbnailStage: RefreshStageProgress(title: "サムネイル取得", completed: 0, total: 0, activeCalls: 0, callsPerSecond: 1)
        )

        let result = await channelSyncService.performForcedRefresh(channelID: channelID)
        RuntimeDiagnostics.shared.record(
            "channel_manual_refresh_fetch_finished",
            detail: result.errorMessage == nil ? "フィード取得成功" : "フィード取得失敗",
            metadata: [
                "channelID": channelID,
                "uncachedVideos": String(result.uncachedVideos.count),
                "error": result.errorMessage ?? ""
            ]
        )
        if result.errorMessage == nil {
            await applyForcedRefreshSuccess(result, channelID: channelID)
        } else {
            applyForcedRefreshFailure()
        }

        let cleanup = isRegisteredChannel ? await performConsistencyMaintenanceIfNeeded(force: false) : nil
        RuntimeDiagnostics.shared.record(
            "channel_manual_refresh_maintenance_finished",
            detail: isRegisteredChannel ? "整合性メンテナンスを完了" : "未登録チャンネルのため整合性メンテナンスを省略",
            metadata: [
                "channelID": channelID,
                "removedVideos": String(cleanup?.removedVideoCount ?? 0),
                "removedThumbnails": String(cleanup?.removedThumbnailCount ?? 0)
            ]
        )
        await refreshUI(
            currentChannelID: channelID,
            isRunning: false,
            lastError: result.errorMessage,
            allowsSuspendedStateUpdate: true
        )
        refreshProgress = .idle
    }

    private func beginManualRefreshProgress(totalChannels: Int) {
        refreshProgress = CacheRefreshProgress(
            isRefreshing: true,
            checkStage: RefreshStageProgress(title: "フィード更新確認", completed: 0, total: totalChannels, activeCalls: 0, callsPerSecond: 3),
            fetchStage: .idle(title: "更新チャンネル取得", callsPerSecond: 0),
            thumbnailStage: .idle(title: "サムネイル取得", callsPerSecond: 0)
        )
    }

    private func runManualRefreshChannels(_ sortedChannels: [String], states: [String: CachedChannelState]) async -> String? {
        var lastError: String?
        var nextIndex = 0

        await withTaskGroup(of: String?.self) { group in
            let initialCount = min(3, sortedChannels.count)
            updateManualRefreshActiveCalls(completed: 0, totalChannels: sortedChannels.count, activeCalls: initialCount)

            for _ in 0 ..< initialCount {
                let channelID = sortedChannels[nextIndex]
                nextIndex += 1
                group.addTask { await self.processChannel(channelID, states: states) }
            }

            while let result = await group.next() {
                if let result {
                    lastError = result
                }

                let completed = refreshProgress.checkStage.completed + 1
                let remaining = sortedChannels.count - completed
                updateManualRefreshActiveCalls(completed: completed, totalChannels: sortedChannels.count, activeCalls: min(3, remaining))

                if nextIndex < sortedChannels.count {
                    let channelID = sortedChannels[nextIndex]
                    nextIndex += 1
                    group.addTask { await self.processChannel(channelID, states: states) }
                }
            }
        }

        return lastError
    }

    private func updateManualRefreshActiveCalls(completed: Int, totalChannels: Int, activeCalls: Int) {
        refreshProgress.checkStage = RefreshStageProgress(
            title: refreshProgress.checkStage.title,
            completed: completed,
            total: totalChannels,
            activeCalls: activeCalls,
            callsPerSecond: refreshProgress.checkStage.callsPerSecond
        )
    }

    private func finishManualRefreshProgress() {
        refreshProgress = CacheRefreshProgress(
            isRefreshing: false,
            checkStage: completedStage(refreshProgress.checkStage),
            fetchStage: completedStage(refreshProgress.fetchStage),
            thumbnailStage: completedStage(refreshProgress.thumbnailStage)
        )
    }

    private func applyForcedRefreshSuccess(_ result: FeedChannelForcedRefreshResult, channelID: String) async {
        refreshProgress.fetchStage = RefreshStageProgress(
            title: refreshProgress.fetchStage.title,
            completed: 0,
            total: 1,
            activeCalls: 1,
            callsPerSecond: refreshProgress.fetchStage.callsPerSecond
        )
        refreshProgress.checkStage = completedStage(refreshProgress.checkStage, total: 1)
        refreshProgress.fetchStage = completedStage(refreshProgress.fetchStage, total: 1)

        let thumbnailTargets = result.uncachedVideos.filter { $0.thumbnailURL != nil }
        refreshProgress.thumbnailStage = RefreshStageProgress(
            title: refreshProgress.thumbnailStage.title,
            completed: 0,
            total: thumbnailTargets.count,
            activeCalls: 0,
            callsPerSecond: refreshProgress.thumbnailStage.callsPerSecond
        )

        for (index, video) in thumbnailTargets.enumerated() {
            await cacheForcedRefreshThumbnail(video, channelID: channelID, index: index, total: thumbnailTargets.count)
        }
    }

    private func cacheForcedRefreshThumbnail(_ video: YouTubeVideo, channelID: String, index: Int, total: Int) async {
        RuntimeDiagnostics.shared.record(
            "channel_manual_refresh_thumbnail_started",
            detail: "サムネイル取得を開始",
            metadata: [
                "channelID": channelID,
                "videoID": video.id,
                "index": String(index + 1),
                "total": String(total)
            ]
        )
        refreshProgress.thumbnailStage = RefreshStageProgress(
            title: refreshProgress.thumbnailStage.title,
            completed: index,
            total: total,
            activeCalls: 1,
            callsPerSecond: refreshProgress.thumbnailStage.callsPerSecond
        )
        await store.cacheThumbnail(for: video)
        RuntimeDiagnostics.shared.record(
            "channel_manual_refresh_thumbnail_finished",
            detail: "サムネイル取得を完了",
            metadata: [
                "channelID": channelID,
                "videoID": video.id,
                "index": String(index + 1)
            ]
        )
        refreshProgress.thumbnailStage = RefreshStageProgress(
            title: refreshProgress.thumbnailStage.title,
            completed: index + 1,
            total: total,
            activeCalls: 0,
            callsPerSecond: refreshProgress.thumbnailStage.callsPerSecond
        )
    }

    private func applyForcedRefreshFailure() {
        refreshProgress.checkStage = completedStage(refreshProgress.checkStage, total: 1)
        refreshProgress.fetchStage = completedStage(refreshProgress.fetchStage, total: 1)
    }

    private func completedStage(_ stage: RefreshStageProgress, total: Int? = nil, completed: Int? = nil) -> RefreshStageProgress {
        let resolvedTotal = total ?? stage.total
        return RefreshStageProgress(
            title: stage.title,
            completed: completed ?? resolvedTotal,
            total: resolvedTotal,
            activeCalls: 0,
            callsPerSecond: stage.callsPerSecond
        )
    }

    private func processChannel(_ channelID: String, states: [String: CachedChannelState]) async -> String? {
        await channelSyncService.processConditionalRefresh(channelID: channelID, state: states[channelID])
    }

    private func prioritizedChannelIDs(states: [String: CachedChannelState]) -> [String] {
        FeedOrdering.prioritizedChannelIDs(channels: channels, states: states)
    }

    private func refreshUI(
        currentChannelID: String?,
        isRunning: Bool,
        lastError: String?,
        includesVideos: Bool = true,
        allowsSuspendedStateUpdate: Bool = false
    ) async {
        let startedAt = Date()
        AppConsoleLogger.appLifecycle.debug(
            "refresh_ui_start",
            metadata: [
                "current_channel": currentChannelID ?? "none",
                "includes_videos": includesVideos ? "true" : "false",
                "allows_suspended": allowsSuspendedStateUpdate ? "true" : "false",
                "main_thread": AppConsoleLogger.mainThreadFlag(),
            ]
        )
        let snapshot = await store.loadSnapshot()
        let snapshotLoadedAt = Date()
        let cachedChannels = snapshot.channels.filter { $0.lastSuccessAt != nil }.count
        let cachedThumbnails = snapshot.videos.filter { $0.thumbnailLocalFilename != nil }.count
        let prioritizedChannels = prioritizedChannelIDs(states: Dictionary(uniqueKeysWithValues: snapshot.channels.map { ($0.channelID, $0) }))
        let currentChannelNumber = currentChannelID.flatMap { prioritizedChannels.firstIndex(of: $0) }.map { $0 + 1 }
        let nextProgress = CacheProgress(
            totalChannels: channels.count,
            cachedChannels: cachedChannels,
            cachedVideos: snapshot.videos.count,
            cachedThumbnails: cachedThumbnails,
            currentChannelID: currentChannelID,
            currentChannelNumber: currentChannelNumber,
            lastUpdatedAt: snapshot.savedAt == .distantPast ? nil : snapshot.savedAt,
            isRunning: isRunning,
            lastError: lastError
        )
        let nextMaintenanceItems = buildMaintenanceItems(from: snapshot)

        if liveUpdateSuspendCount > 0, !allowsSuspendedStateUpdate {
            needsRefreshWhenResumed = true
            RuntimeDiagnostics.shared.record(
                "refresh_ui_deferred",
                detail: "ライブ更新抑止中のため UI 反映を保留",
                metadata: [
                    "currentChannelID": currentChannelID ?? "",
                    "suspendCount": String(liveUpdateSuspendCount),
                    "maintenanceCount": String(nextMaintenanceItems.count)
                ]
            )
            return
        }

        progress = nextProgress
        maintenanceItems = nextMaintenanceItems
        RuntimeDiagnostics.shared.record(
            "refresh_ui_applied",
            detail: "UI 状態を反映",
            metadata: [
                "currentChannelID": currentChannelID ?? "",
                "maintenanceCount": String(nextMaintenanceItems.count),
                "cachedVideos": String(nextProgress.cachedVideos),
                "cachedChannels": String(nextProgress.cachedChannels),
                "includesVideos": includesVideos ? "true" : "false"
            ]
        )
        await refreshHomeSystemStatus(snapshot: snapshot, currentProgress: nextProgress)
        let homeStatusUpdatedAt = Date()

        await store.persistBootstrap(progress: progress, maintenanceItems: maintenanceItems)
        let persistedAt = Date()

        if includesVideos {
            videos = await store.loadVideos(query: videoQuery)
        }
        AppConsoleLogger.appLifecycle.notice(
            "refresh_ui_complete",
            metadata: [
                "current_channel": currentChannelID ?? "none",
                "includes_videos": includesVideos ? "true" : "false",
                "snapshot_ms": AppConsoleLogger.elapsedMilliseconds(from: startedAt, to: snapshotLoadedAt),
                "home_status_ms": AppConsoleLogger.elapsedMilliseconds(from: snapshotLoadedAt, to: homeStatusUpdatedAt),
                "persist_ms": AppConsoleLogger.elapsedMilliseconds(from: homeStatusUpdatedAt, to: persistedAt),
                "videos_ms": includesVideos ? AppConsoleLogger.elapsedMilliseconds(from: persistedAt, to: Date()) : "0",
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                "main_thread": AppConsoleLogger.mainThreadFlag(),
            ]
        )
    }

    private func buildMaintenanceItems(from snapshot: FeedCacheSnapshot) -> [ChannelMaintenanceItem] {
        let prioritizedChannels = prioritizedChannelIDs(states: Dictionary(uniqueKeysWithValues: snapshot.channels.map { ($0.channelID, $0) }))
        return prioritizedChannels.map { channelID in
            let state = snapshot.channels.first(where: { $0.channelID == channelID })
            return ChannelMaintenanceItem(
                id: channelID,
                channelID: channelID,
                channelTitle: state?.channelTitle,
                lastSuccessAt: state?.lastSuccessAt,
                lastCheckedAt: state?.lastCheckedAt,
                latestPublishedAt: state?.latestPublishedAt,
                cachedVideoCount: state?.cachedVideoCount ?? 0,
                lastError: state?.lastError,
                freshness: freshness(for: state?.lastSuccessAt)
            )
        }
    }

    private func freshness(for lastSuccessAt: Date?) -> ChannelFreshness {
        FeedOrdering.freshness(lastSuccessAt: lastSuccessAt, freshnessInterval: freshnessInterval)
    }

    private func scheduleImportedChannelRefresh(channelIDs: [String]) {
        guard !channelIDs.isEmpty else { return }
        guard importRefreshTask == nil else { return }

        importRefreshTask = Task {
            await refreshImportedChannels(channelIDs)
            importRefreshTask = nil
        }
    }

    private func refreshImportedChannels(_ importedChannelIDs: [String]) async {
        let snapshot = await store.loadSnapshot()
        let states = Dictionary(uniqueKeysWithValues: snapshot.channels.map { ($0.channelID, $0) })
        let cachedVideoChannelIDs = Set(snapshot.videos.map(\.channelID))
        let prioritizedChannelIDs = importedChannelIDs.sorted { lhs, rhs in
            let lhsNeedsWarmup = states[lhs]?.channelTitle == nil || !cachedVideoChannelIDs.contains(lhs)
            let rhsNeedsWarmup = states[rhs]?.channelTitle == nil || !cachedVideoChannelIDs.contains(rhs)
            if lhsNeedsWarmup != rhsNeedsWarmup {
                return lhsNeedsWarmup && !rhsNeedsWarmup
            }
            return lhs < rhs
        }

        await withTaskGroup(of: Void.self) { group in
            var nextIndex = 0
            let initialCount = min(3, prioritizedChannelIDs.count)

            for _ in 0 ..< initialCount {
                let channelID = prioritizedChannelIDs[nextIndex]
                nextIndex += 1
                group.addTask {
                    _ = await self.processChannel(channelID, states: states)
                }
            }

            while await group.next() != nil {
                if nextIndex < prioritizedChannelIDs.count {
                    let channelID = prioritizedChannelIDs[nextIndex]
                    nextIndex += 1
                    group.addTask {
                        _ = await self.processChannel(channelID, states: states)
                    }
                }
            }
        }

        _ = await performConsistencyMaintenanceIfNeeded(force: false)
        await refreshUI(currentChannelID: nil, isRunning: false, lastError: progress.lastError)
    }

    private func performConsistencyMaintenanceIfNeeded(force: Bool) async -> CacheConsistencyMaintenanceResult? {
        guard force || !channels.isEmpty else { return nil }
        return await store.performConsistencyMaintenance(activeChannelIDs: channels, force: force)
    }

    private func refreshHomeSystemStatus(snapshot: FeedCacheSnapshot? = nil, currentProgress: CacheProgress? = nil) async {
        homeSystemStatus = await homeSystemStatusService.loadStatus(
            snapshot: snapshot,
            currentProgress: currentProgress
        )
    }

    func clearRemoteSearchHistory(keyword: String) async {
        await remoteSearchService.clear(keyword: keyword)
        await refreshHomeSystemStatus()
    }

    private func performManagedRemoteRefresh(
        keyword: String,
        limit: Int,
        logger: AppConsoleLogger,
        fallbackOnFailure: String
    ) async -> VideoSearchResult {
        let key = RemoteSearchTaskKey(keyword: keyword, limit: limit)

        let task: Task<VideoSearchResult, Never>
        if let existingTask = remoteSearchTasks[key] {
            task = existingTask
        } else {
            task = Task { [remoteSearchService] in
                do {
                    return try await remoteSearchService.refresh(keyword: keyword, limit: limit)
                } catch {
                    return await Self.resolveRemoteRefreshFailure(
                        error: error,
                        keyword: keyword,
                        limit: limit,
                        logger: logger,
                        remoteSearchService: remoteSearchService,
                        fallbackOnFailure: fallbackOnFailure
                    )
                }
            }
            remoteSearchTasks[key] = task
        }

        let result = await task.value
        remoteSearchTasks[key] = nil
        await refreshHomeSystemStatus()
        return result
    }

    private nonisolated static func resolveRemoteRefreshFailure(
        error: Error,
        keyword: String,
        limit: Int,
        logger: AppConsoleLogger,
        remoteSearchService: RemoteVideoSearchService,
        fallbackOnFailure: String
    ) async -> VideoSearchResult {
        let keywordPreview = AppConsoleLogger.sanitizedKeyword(keyword)
        if RemoteSearchErrorPolicy.isCancellation(error) {
            if let cached = await remoteSearchService.loadSnapshot(keyword: keyword, limit: limit, allowExpired: true) {
                logger.notice(
                    "refresh_cancelled",
                    metadata: [
                        "keyword": keywordPreview,
                        "fallback": cached.source == .staleRemoteCache ? "stale_cache" : "cache",
                        "videos": String(cached.videos.count),
                        "reason": RemoteSearchErrorPolicy.diagnosticReason(for: error),
                    ]
                )
                return VideoSearchResult(
                    keyword: cached.keyword,
                    videos: cached.videos,
                    totalCount: cached.totalCount,
                    source: cached.source,
                    fetchedAt: cached.fetchedAt,
                    expiresAt: cached.expiresAt
                )
            }
            logger.notice(
                "refresh_cancelled",
                metadata: [
                    "keyword": keywordPreview,
                    "fallback": "empty",
                    "reason": RemoteSearchErrorPolicy.diagnosticReason(for: error),
                ]
            )
            return VideoSearchResult(
                keyword: keyword,
                videos: [],
                totalCount: 0,
                source: .remoteCache
            )
        }

        if let cached = await remoteSearchService.loadSnapshot(keyword: keyword, limit: limit, allowExpired: true) {
            logger.error(
                "refresh_failed",
                message: AppConsoleLogger.errorSummary(error),
                metadata: [
                    "keyword": keywordPreview,
                    "fallback": "stale_cache",
                    "videos": String(cached.videos.count),
                ]
            )
            return VideoSearchResult(
                keyword: cached.keyword,
                videos: cached.videos,
                totalCount: cached.totalCount,
                source: .staleRemoteCache,
                fetchedAt: cached.fetchedAt,
                expiresAt: cached.expiresAt,
                errorMessage: RemoteSearchErrorPolicy.userMessage(for: error)
            )
        }

        logger.error(
            "refresh_failed",
            message: AppConsoleLogger.errorSummary(error),
            metadata: ["keyword": keywordPreview, "fallback": fallbackOnFailure]
        )
        return VideoSearchResult(
            keyword: keyword,
            videos: [],
            totalCount: 0,
            source: .remoteAPI,
            errorMessage: RemoteSearchErrorPolicy.userMessage(for: error)
        )
    }
}

private struct RemoteSearchTaskKey: Hashable {
    let keyword: String
    let limit: Int
}
