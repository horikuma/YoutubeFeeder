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

    private var channels: [String]
    private let store = FeedCacheStore()
    private let feedService = YouTubeFeedService()
    private let channelResolver = YouTubeChannelResolver()
    private var manualRefreshTask: Task<Void, Never>?
    private var importRefreshTask: Task<Void, Never>?
    private var freshnessInterval: TimeInterval
    private var videoQuery = VideoQuery()
    private var liveUpdateSuspendCount = 0
    private var needsRefreshWhenResumed = false

    private var channelSyncService: FeedChannelSyncService {
        FeedChannelSyncService(store: store, feedService: feedService)
    }

    init(channels: [String], freshnessInterval: TimeInterval? = nil) {
        self.channels = channels
        self.freshnessInterval = freshnessInterval ?? TimeInterval(max(channels.count, 1) * 60)
        let bootstrap = FeedBootstrapStore.load(channels: channels)
        self.progress = bootstrap.progress
        self.maintenanceItems = bootstrap.maintenanceItems
    }

    func bootstrapMaintenance() async {
        channels = ChannelRegistryStore.loadPersistedOrSeededChannelIDs()
        freshnessInterval = TimeInterval(max(channels.count, 1) * 60)
        _ = await performConsistencyMaintenanceIfNeeded(force: false)
        let bootstrap = FeedBootstrapStore.load(channels: channels)
        progress = bootstrap.progress
        maintenanceItems = bootstrap.maintenanceItems
    }

    func suspendLiveUpdates() {
        liveUpdateSuspendCount += 1
    }

    func resumeLiveUpdates() {
        liveUpdateSuspendCount = max(liveUpdateSuspendCount - 1, 0)

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
        guard !normalizedChannelID.isEmpty else { return }
        guard channels.contains(normalizedChannelID) else { return }
        guard manualRefreshTask == nil else { return }

        manualRefreshTask = Task {
            StartupDiagnostics.shared.mark("channelManualRefreshStarted")
            lastManualChannelRefreshID = normalizedChannelID
            if AppLaunchMode.current.usesMockData {
                await performMockChannelRefresh(channelID: normalizedChannelID)
            } else {
                await performManualChannelRefresh(channelID: normalizedChannelID)
            }
            StartupDiagnostics.shared.mark("channelManualRefreshFinished")
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
        await store.loadVideos(query: VideoQuery(limit: 50, channelID: channelID, keyword: nil, sortOrder: .publishedDescending, excludeShorts: true))
    }

    func addChannel(input: String) async throws -> ChannelRegistrationFeedback {
        let resolvedChannel = try await channelResolver.resolve(input: input)
        let didAdd = try ChannelRegistryStore.addChannelID(resolvedChannel.channelID)
        channels = ChannelRegistryStore.loadPersistedOrSeededChannelIDs()
        freshnessInterval = TimeInterval(max(channels.count, 1) * 60)
        _ = await performConsistencyMaintenanceIfNeeded(force: false)

        let latestFeedError: String?
        let cachedItem: ChannelBrowseItem?
        do {
            let result = try await feedService.fetchLatestFeed(for: resolvedChannel.channelID)
            let uncachedVideos = await store.recordSuccess(
                channelID: resolvedChannel.channelID,
                videos: result.videos,
                metadata: result.metadata
            )
            for video in uncachedVideos where video.thumbnailURL != nil {
                await store.cacheThumbnail(for: video)
            }
            latestFeedError = nil
            let registeredAtByChannelID = [resolvedChannel.channelID: ChannelRegistryStore.registrationDate(for: resolvedChannel.channelID)]
            cachedItem = await store.loadChannelBrowseItems(
                channelIDs: [resolvedChannel.channelID],
                registeredAtByChannelID: registeredAtByChannelID
            ).first
        } catch {
            latestFeedError = error.localizedDescription
            let registeredAtByChannelID = [resolvedChannel.channelID: ChannelRegistryStore.registrationDate(for: resolvedChannel.channelID)]
            cachedItem = await store.loadChannelBrowseItems(
                channelIDs: [resolvedChannel.channelID],
                registeredAtByChannelID: registeredAtByChannelID
            ).first
        }

        await refreshUI(currentChannelID: nil, isRunning: false, lastError: progress.lastError, includesVideos: false)

        let channelTitle = cachedItem?.channelTitle.isEmpty == false ? cachedItem?.channelTitle : nil
        return ChannelRegistrationFeedback(
            status: didAdd ? .added : .alreadyRegistered,
            channelID: resolvedChannel.channelID,
            channelTitle: channelTitle ?? resolvedChannel.channelID,
            latestVideoTitle: cachedItem?.latestVideo?.title,
            latestPublishedAt: cachedItem?.latestPublishedAt,
            cachedVideoCount: cachedItem?.cachedVideoCount ?? 0,
            latestFeedError: latestFeedError
        )
    }

    func removeChannel(_ channelID: String) async -> ChannelRemovalFeedback? {
        let normalizedChannelID = channelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedChannelID.isEmpty else { return nil }

        let channelTitle = maintenanceItems.first(where: { $0.channelID == normalizedChannelID })?.channelTitle
            ?? videos.first(where: { $0.channelID == normalizedChannelID })?.channelTitle
            ?? normalizedChannelID

        guard (try? ChannelRegistryStore.removeChannelID(normalizedChannelID)) == true else {
            return nil
        }

        channels = ChannelRegistryStore.loadPersistedOrSeededChannelIDs()
        freshnessInterval = TimeInterval(max(channels.count, 1) * 60)
        let cleanup = await performConsistencyMaintenanceIfNeeded(force: true)
        await refreshUI(currentChannelID: nil, isRunning: false, lastError: progress.lastError)

        return ChannelRemovalFeedback(
            channelID: normalizedChannelID,
            channelTitle: channelTitle,
            removedVideoCount: cleanup?.removedVideoCount ?? 0,
            removedThumbnailCount: cleanup?.removedThumbnailCount ?? 0
        )
    }

    func exportChannelRegistry(backend: ChannelRegistryTransferBackend) throws -> ChannelRegistryTransferFeedback {
        let result = try ChannelRegistryTransferStore.export(backend: backend)
        return ChannelRegistryTransferFeedback(
            action: .export,
            backend: result.backend,
            channelCount: result.channelCount,
            path: result.fileURL.path(percentEncoded: false),
            refreshMessage: nil
        )
    }

    func importChannelRegistry(backend: ChannelRegistryTransferBackend) async throws -> ChannelRegistryTransferFeedback {
        let result = try ChannelRegistryTransferStore.import(backend: backend)
        channels = ChannelRegistryStore.loadPersistedOrSeededChannelIDs()
        freshnessInterval = TimeInterval(max(channels.count, 1) * 60)
        _ = await performConsistencyMaintenanceIfNeeded(force: true)
        await bootstrapMaintenance()

        let refreshMessage: String?
        if AppLaunchMode.current.usesMockData {
            refreshMessage = "UI テストモードでは最新情報の再取得を省略しました。"
        } else {
            scheduleImportedChannelRefresh(channelIDs: channels)
            refreshMessage = "最新情報の再取得をバックグラウンドで開始しました。"
        }

        return ChannelRegistryTransferFeedback(
            action: .import,
            backend: result.backend,
            channelCount: result.channelCount,
            path: result.fileURL.path(percentEncoded: false),
            refreshMessage: refreshMessage
        )
    }

    private func performManualRefresh() async {
        let snapshot = await store.loadSnapshot()
        let states = Dictionary(uniqueKeysWithValues: snapshot.channels.map { ($0.channelID, $0) })
        let sortedChannels = prioritizedChannelIDs(states: states)
        var lastError: String?
        let totalChannels = sortedChannels.count

        refreshProgress = CacheRefreshProgress(
            isRefreshing: true,
            checkStage: RefreshStageProgress(title: "フィード更新確認", completed: 0, total: totalChannels, activeCalls: 0, callsPerSecond: 3),
            fetchStage: .idle(title: "更新チャンネル取得", callsPerSecond: 0),
            thumbnailStage: .idle(title: "サムネイル取得", callsPerSecond: 0)
        )

        var nextIndex = 0
        await withTaskGroup(of: String?.self) { group in
            let initialCount = min(3, totalChannels)
            refreshProgress.checkStage = RefreshStageProgress(
                title: refreshProgress.checkStage.title,
                completed: 0,
                total: refreshProgress.checkStage.total,
                activeCalls: initialCount,
                callsPerSecond: refreshProgress.checkStage.callsPerSecond
            )

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
                let remaining = totalChannels - completed
                let activeCalls = min(3, remaining)
                refreshProgress.checkStage = RefreshStageProgress(
                    title: refreshProgress.checkStage.title,
                    completed: completed,
                    total: refreshProgress.checkStage.total,
                    activeCalls: activeCalls,
                    callsPerSecond: refreshProgress.checkStage.callsPerSecond
                )

                if nextIndex < totalChannels {
                    let channelID = sortedChannels[nextIndex]
                    nextIndex += 1
                    group.addTask { await self.processChannel(channelID, states: states) }
                }
            }
        }

        refreshProgress = CacheRefreshProgress(
            isRefreshing: false,
            checkStage: RefreshStageProgress(
                title: refreshProgress.checkStage.title,
                completed: refreshProgress.checkStage.completed,
                total: refreshProgress.checkStage.total,
                activeCalls: 0,
                callsPerSecond: refreshProgress.checkStage.callsPerSecond
            ),
            fetchStage: RefreshStageProgress(
                title: refreshProgress.fetchStage.title,
                completed: refreshProgress.fetchStage.completed,
                total: refreshProgress.fetchStage.total,
                activeCalls: 0,
                callsPerSecond: refreshProgress.fetchStage.callsPerSecond
            ),
            thumbnailStage: RefreshStageProgress(
                title: refreshProgress.thumbnailStage.title,
                completed: refreshProgress.thumbnailStage.completed,
                total: refreshProgress.thumbnailStage.total,
                activeCalls: 0,
                callsPerSecond: refreshProgress.thumbnailStage.callsPerSecond
            )
        )
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
        refreshProgress = CacheRefreshProgress(
            isRefreshing: true,
            checkStage: RefreshStageProgress(title: "チャンネル更新", completed: 0, total: 1, activeCalls: 1, callsPerSecond: 1),
            fetchStage: .idle(title: "更新チャンネル取得", callsPerSecond: 0),
            thumbnailStage: .idle(title: "サムネイル取得", callsPerSecond: 0)
        )
        await refreshUI(currentChannelID: channelID, isRunning: false, lastError: progress.lastError)
        refreshProgress = .idle
    }

    private func performManualChannelRefresh(channelID: String) async {
        refreshProgress = CacheRefreshProgress(
            isRefreshing: true,
            checkStage: RefreshStageProgress(title: "チャンネル更新", completed: 0, total: 1, activeCalls: 1, callsPerSecond: 1),
            fetchStage: RefreshStageProgress(title: "更新チャンネル取得", completed: 0, total: 1, activeCalls: 0, callsPerSecond: 1),
            thumbnailStage: RefreshStageProgress(title: "サムネイル取得", completed: 0, total: 0, activeCalls: 0, callsPerSecond: 1)
        )

        let lastError: String?

        let result = await channelSyncService.performForcedRefresh(channelID: channelID)
        if result.errorMessage == nil {
            refreshProgress.fetchStage = RefreshStageProgress(
                title: refreshProgress.fetchStage.title,
                completed: 0,
                total: 1,
                activeCalls: 1,
                callsPerSecond: refreshProgress.fetchStage.callsPerSecond
            )

            refreshProgress.checkStage = RefreshStageProgress(
                title: refreshProgress.checkStage.title,
                completed: 1,
                total: 1,
                activeCalls: 0,
                callsPerSecond: refreshProgress.checkStage.callsPerSecond
            )
            refreshProgress.fetchStage = RefreshStageProgress(
                title: refreshProgress.fetchStage.title,
                completed: 1,
                total: 1,
                activeCalls: 0,
                callsPerSecond: refreshProgress.fetchStage.callsPerSecond
            )
            refreshProgress.thumbnailStage = RefreshStageProgress(
                title: refreshProgress.thumbnailStage.title,
                completed: 0,
                total: result.uncachedVideos.filter { $0.thumbnailURL != nil }.count,
                activeCalls: 0,
                callsPerSecond: refreshProgress.thumbnailStage.callsPerSecond
            )

            for (index, video) in result.uncachedVideos.filter({ $0.thumbnailURL != nil }).enumerated() {
                refreshProgress.thumbnailStage = RefreshStageProgress(
                    title: refreshProgress.thumbnailStage.title,
                    completed: index,
                    total: refreshProgress.thumbnailStage.total,
                    activeCalls: 1,
                    callsPerSecond: refreshProgress.thumbnailStage.callsPerSecond
                )
                await store.cacheThumbnail(for: video)
                refreshProgress.thumbnailStage = RefreshStageProgress(
                    title: refreshProgress.thumbnailStage.title,
                    completed: index + 1,
                    total: refreshProgress.thumbnailStage.total,
                    activeCalls: 0,
                    callsPerSecond: refreshProgress.thumbnailStage.callsPerSecond
                )
            }
        } else {
            refreshProgress.checkStage = RefreshStageProgress(
                title: refreshProgress.checkStage.title,
                completed: 1,
                total: 1,
                activeCalls: 0,
                callsPerSecond: refreshProgress.checkStage.callsPerSecond
            )
            refreshProgress.fetchStage = RefreshStageProgress(
                title: refreshProgress.fetchStage.title,
                completed: 1,
                total: 1,
                activeCalls: 0,
                callsPerSecond: refreshProgress.fetchStage.callsPerSecond
            )
        }
        lastError = result.errorMessage

        _ = await performConsistencyMaintenanceIfNeeded(force: false)
        await refreshUI(currentChannelID: channelID, isRunning: false, lastError: lastError)
        refreshProgress = .idle
    }

    private func processChannel(_ channelID: String, states: [String: CachedChannelState]) async -> String? {
        await channelSyncService.processConditionalRefresh(channelID: channelID, state: states[channelID])
    }

    private func prioritizedChannelIDs(states: [String: CachedChannelState]) -> [String] {
        FeedOrdering.prioritizedChannelIDs(channels: channels, states: states)
    }

    private func refreshUI(currentChannelID: String?, isRunning: Bool, lastError: String?, includesVideos: Bool = true) async {
        let snapshot = await store.loadSnapshot()
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

        if liveUpdateSuspendCount > 0 {
            needsRefreshWhenResumed = true
            return
        }

        progress = nextProgress
        maintenanceItems = nextMaintenanceItems

        await store.persistBootstrap(progress: progress, maintenanceItems: maintenanceItems)

        if includesVideos {
            videos = await store.loadVideos(query: videoQuery)
        }
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
}
