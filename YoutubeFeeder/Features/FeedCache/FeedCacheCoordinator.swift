import Foundation
import Combine

@MainActor
final class FeedCacheCoordinator: ObservableObject {
    @Published var progress: CacheProgress
    @Published var maintenanceItems: [ChannelMaintenanceItem] = []
    @Published var videos: [CachedVideo] = []
    @Published var refreshProgress: CacheRefreshProgress = .idle
    @Published var manualRefreshCount: Int = 0
    @Published var lastManualChannelRefreshID: String?
    @Published var homeSystemStatus = HomeSystemStatus.empty(keyword: FeedCacheCoordinator.homeSearchKeyword)

    var channels: [String]
    let readService: FeedCacheReadService
    let writeService: FeedCacheWriteService
    let channelSyncService: FeedChannelSyncService
    let remoteSearchService: RemoteVideoSearchService
    let homeSystemStatusService: HomeSystemStatusService
    let channelRegistryMaintenanceService: ChannelRegistryMaintenanceService
    var manualRefreshTask: Task<Void, Never>?
    var importRefreshTask: Task<Void, Never>?
    var freshnessInterval: TimeInterval
    var videoQuery = VideoQuery()
    var liveUpdateSuspendCount = 0
    var needsRefreshWhenResumed = false
    var remoteSearchTasks: [RemoteSearchTaskKey: Task<VideoSearchResult, Never>] = [:]
    var remoteSearchSnapshotCache: [String: VideoSearchResult] = [:]
    var remoteSearchPrewarmTasks: [String: Task<Void, Never>] = [:]
    let remoteSearchCacheLifetime: TimeInterval = 12 * 60 * 60

    static let homeSearchKeyword = "ゆっくり実況"

    init(
        channels: [String],
        dependencies: FeedCacheDependencies,
        freshnessInterval: TimeInterval? = nil
    ) {
        let remoteSearchService = RemoteVideoSearchService(
            searchService: dependencies.searchService,
            cacheStore: dependencies.remoteSearchCacheStore,
            cacheLifetime: 12 * 60 * 60
        )
        let readService = FeedCacheReadService(store: dependencies.store, remoteSearchService: remoteSearchService)
        let writeService = FeedCacheWriteService(store: dependencies.store)
        self.channels = channels
        self.readService = readService
        self.writeService = writeService
        self.channelSyncService = FeedChannelSyncService(writer: writeService, feedService: dependencies.feedService)
        self.remoteSearchService = remoteSearchService
        self.homeSystemStatusService = HomeSystemStatusService(
            readService: readService,
            remoteSearchService: remoteSearchService,
            homeSearchKeyword: Self.homeSearchKeyword
        )
        self.channelRegistryMaintenanceService = ChannelRegistryMaintenanceService(
            readService: readService,
            writer: writeService,
            feedService: dependencies.feedService,
            channelResolver: dependencies.channelResolver,
            remoteSearchService: remoteSearchService
        )
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
            videos = await readService.loadVideos(query: videoQuery)
        }
    }

    func loadChannelBrowseItems(sortDescriptor: ChannelBrowseSortDescriptor = .default) async -> [ChannelBrowseItem] {
        let channelIDs = maintenanceItems.map(\.channelID).isEmpty ? channels : maintenanceItems.map(\.channelID)
        let registeredAtByChannelID = dictionaryKeepingLastValue(
            ChannelRegistryStore.loadAllChannels().map { ($0.channelID, $0.addedAt) }
        )
        return await readService.loadChannelBrowseItems(
            channelIDs: channelIDs,
            registeredAtByChannelID: registeredAtByChannelID,
            sortDescriptor: sortDescriptor
        )
    }

    func loadVideosForChannel(_ channelID: String) async -> [CachedVideo] {
        await readService.loadMergedVideosForChannel(channelID)
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
        mergedVideos = await loadRemoteSearchChannelFallbackIfNeeded(context: context, currentVideos: mergedVideos)
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

        let cachedVideos = await readService.loadVideos(
            query: VideoQuery(limit: .max, channelID: channelID, keyword: nil, sortOrder: .publishedDescending, excludeShorts: true)
        )
        return ChannelVideosAutoRefreshPolicy.shouldRefresh(
            cachedChannelVideos: cachedVideos,
            selectedVideoID: context.selectedVideoID,
            routeSource: context.routeSource
        )
    }

    func searchVideos(keyword: String, limit: Int = 20) async -> VideoSearchResult {
        await readService.searchVideos(keyword: keyword, limit: limit)
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
        await completeImportedChannelUpdate(
            channels: execution.channels,
            importedChannelIDs: execution.channels
        )

        return execution.feedback
    }

    func importChannelCSV(data: Data, fileURL: URL) async throws -> ChannelCSVImportFeedback {
        let execution = try channelRegistryMaintenanceService.importChannelsCSV(
            data: data,
            fileURL: fileURL,
            usesMockData: AppLaunchMode.current.usesMockData
        )
        await completeImportedChannelUpdate(
            channels: execution.channels,
            importedChannelIDs: execution.importedChannelIDs
        )
        return execution.feedback
    }

    func resetAllSettings() async throws -> LocalStateResetFeedback {
        let feedback = try await channelRegistryMaintenanceService.resetAllSettings()

        resetRemoteSearchSnapshotCache()
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

    func processChannel(_ channelID: String, states: [String: CachedChannelState]) async -> String? {
        await channelSyncService.processConditionalRefresh(channelID: channelID, state: states[channelID])
    }

    func prioritizedChannelIDs(states: [String: CachedChannelState]) -> [String] {
        FeedOrdering.prioritizedChannelIDs(channels: channels, states: states)
    }

    func dictionaryKeepingLastValue<Value>(_ pairs: [(String, Value)]) -> [String: Value] {
        Dictionary(pairs, uniquingKeysWith: { _, rhs in rhs })
    }

    func performConsistencyMaintenanceIfNeeded(force: Bool) async -> CacheConsistencyMaintenanceResult? {
        guard force || !channels.isEmpty else { return nil }
        return await writeService.performConsistencyMaintenance(activeChannelIDs: channels, force: force)
    }

    func refreshHomeSystemStatus(snapshot: FeedCacheSnapshot? = nil, currentProgress: CacheProgress? = nil) async {
        homeSystemStatus = await homeSystemStatusService.loadStatus(
            snapshot: snapshot,
            currentProgress: currentProgress
        )
    }
}
