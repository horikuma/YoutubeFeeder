import Foundation
import Combine

@MainActor
final class FeedCacheCoordinator: ObservableObject {
    nonisolated static let maximumConcurrentChannelRefreshes = 3

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
    let channelPlaylistBrowseService: ChannelPlaylistBrowseService
    let homeSystemStatusService: HomeSystemStatusService
    let channelRegistryMaintenanceService: ChannelRegistryMaintenanceService
    let channelRegistrySyncService: ChannelRegistryCloudflareSyncService
    var manualRefreshTask: Task<FeedRefreshCycleResult?, Never>?
    var automaticRefreshTask: Task<Void, Never>?
    var importRefreshTask: Task<Void, Never>?
    var freshnessInterval: TimeInterval
    var videoQuery = VideoQuery()
    var remoteSearchTasks: [RemoteSearchTaskKey: Task<VideoSearchResult, Never>] = [:]
    var remoteSearchSnapshotCache: [String: VideoSearchResult] = [:]
    var remoteSearchPrewarmTasks: [String: Task<Void, Never>] = [:]
    let remoteSearchCacheLifetime: TimeInterval = 12 * 60 * 60

    static let homeSearchKeyword = "ゆっくり実況"

    var isChannelRefreshRunning: Bool {
        manualRefreshTask != nil
            || importRefreshTask != nil
    }

    init(
        channels: [String],
        dependencies: FeedCacheDependencies,
        freshnessInterval: TimeInterval? = nil
    ) {
        let remoteSearchService = RemoteVideoSearchService(
            searchService: dependencies.searchService
        )
        let channelPlaylistBrowseService = ChannelPlaylistBrowseService(
            playlistService: dependencies.playlistService
        )
        let readService = FeedCacheReadService(
            store: dependencies.store,
            remoteSearchCacheStore: dependencies.remoteSearchCacheStore
        )
        let writeService = FeedCacheWriteService(
            store: dependencies.store,
            remoteSearchCacheStore: dependencies.remoteSearchCacheStore
        )
        self.channels = channels
        self.readService = readService
        self.writeService = writeService
        self.channelSyncService = FeedChannelSyncService(writer: writeService, feedService: dependencies.feedService)
        self.remoteSearchService = remoteSearchService
        self.channelPlaylistBrowseService = channelPlaylistBrowseService
        self.homeSystemStatusService = HomeSystemStatusService(
            readService: readService,
            apiKeyConfigured: remoteSearchService.isConfigured,
            homeSearchKeyword: Self.homeSearchKeyword,
            remoteSearchCacheLifetime: remoteSearchCacheLifetime
        )
        self.channelRegistrySyncService = dependencies.channelRegistrySyncService
        self.channelRegistryMaintenanceService = ChannelRegistryMaintenanceService(
            readService: readService,
            writer: writeService,
            feedService: dependencies.feedService,
            channelResolver: dependencies.channelResolver
        )
        self.freshnessInterval = freshnessInterval ?? TimeInterval(max(channels.count, 1) * 60)
        let bootstrap = FeedBootstrapStore.load(channels: channels)
        self.progress = bootstrap.progress
        self.maintenanceItems = bootstrap.maintenanceItems
    }

    func bootstrapMaintenance() async {
        let startedAt = Date()
        syncRegisteredChannelsFromStore(reason: "bootstrap")
        freshnessInterval = TimeInterval(max(channels.count, 1) * 60)
        _ = await performConsistencyMaintenanceIfNeeded(force: false)
        let bootstrap = FeedBootstrapStore.load(channels: channels)
        progress = bootstrap.progress
        maintenanceItems = bootstrap.maintenanceItems
        await refreshHomeSystemStatus()
        startChannelRegistrySyncIfNeeded()
        AppConsoleLogger.appLifecycle.info(
            "bootstrap_coordinator_complete",
            metadata: [
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                "channels": String(channels.count),
                "maintenance_items": String(maintenanceItems.count)
            ]
        )
    }

    func loadSnapshot() async -> FeedCacheSnapshot {
        var snapshot = await readService.loadSnapshot()
        snapshot.registeredChannelIDs = channels
        snapshot.maintenanceItems = maintenanceItems
        snapshot.registeredAtByChannelID = Dictionary(
            ChannelRegistryStore.loadAllChannels().map { ($0.channelID, $0.addedAt) },
            uniquingKeysWith: { _, rhs in rhs }
        )
        return snapshot
    }

    func refresh(intent: FeedCacheIntent) async -> FeedCacheResult {
        switch intent {
        case .home:
            await refreshCacheManually()
            return .home
        case let .channel(context):
            await refreshChannelManually(context.channelID)
            return .channelVideos(await loadVideosForChannel(context.channelID))
        case let .channelVideos(channelID):
            return .channelVideos(await loadVideosForChannel(channelID))
        case let .channelVideosNextPage(channelID):
            let snapshot = await loadSnapshot()
            let page = await loadChannelVideosPage(
                channelID: channelID,
                pageToken: snapshot.nextPageToken(for: channelID),
                limit: 50
            )
            return .channelVideoPage(page)
        case let .removeChannel(channelID):
            guard let feedback = await removeChannel(channelID) else {
                return .home
            }
            await writeService.saveChannelNextPageToken(nil, channelID: channelID)
            return .channelRemoval(feedback)
        case let .remoteSearch(keyword, limit):
            return .remoteSearch(await search(keyword: keyword, limit: limit, forceRefresh: true))
        }
    }

    func refreshCacheManually() async {
        guard !dropChannelRefreshTriggerIfRunning("manual_home_refresh") else { return }
        syncRegisteredChannelsFromStore(reason: "manual_refresh")

        AppConsoleLogger.appLifecycle.info(
            "refresh_cache_manual_started",
            metadata: [
                "channels": String(channels.count),
                "current_channel": progress.currentChannelID ?? "",
                "is_running": progress.isRunning ? "true" : "false"
            ]
        )
        manualRefreshTask = Task {
            StartupDiagnostics.shared.mark("manualRefreshStarted")
            manualRefreshCount += 1
            if AppLaunchMode.current.usesMockData {
                await performMockRefresh()
            } else {
                await performManualRefresh()
            }
            StartupDiagnostics.shared.mark("manualRefreshFinished")
            return nil
        }
        _ = await manualRefreshTask?.value
        manualRefreshTask = nil
        AppConsoleLogger.appLifecycle.info(
            "refresh_cache_manual_finished",
            metadata: [
                "channels": String(channels.count),
                "current_channel": progress.currentChannelID ?? "",
                "is_running": progress.isRunning ? "true" : "false"
            ]
        )
    }

    func refreshChannelManually(_ channelID: String) async {
        syncRegisteredChannelsFromStore(reason: "channel_refresh")
        let normalizedChannelID = channelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedChannelID.isEmpty else {
            RuntimeDiagnostics.shared.record("channel_manual_refresh_ignored", detail: "空の channelID のため更新しない")
            return
        }
        guard !dropChannelRefreshTriggerIfRunning(
            "manual_channel_refresh",
            metadata: ["channelID": normalizedChannelID]
        ) else { return }

        let startedAt = Date()
        manualRefreshTask = Task {
            StartupDiagnostics.shared.mark("channelManualRefreshStarted")
            AppConsoleLogger.appLifecycle.info(
                "channel_manual_refresh_started",
                metadata: [
                    "channelID": normalizedChannelID,
                    "result_state": "running"
                ]
            )
            RuntimeDiagnostics.shared.record(
                "channel_manual_refresh_started",
                detail: "チャンネル単独更新を開始",
                metadata: [
                    "channelID": normalizedChannelID
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
            AppConsoleLogger.appLifecycle.info(
                "channel_manual_refresh_finished",
                metadata: [
                    "channelID": normalizedChannelID,
                    "result_state": progress.lastError == nil ? "completed" : "completed_with_errors",
                    "lastError": progress.lastError ?? "",
                    "cachedVideoCount": String(updatedItem?.cachedVideoCount ?? 0),
                    "latestPublishedAt": updatedItem?.latestPublishedAt?.formatted(date: .numeric, time: .standard) ?? "",
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
                ]
            )
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
            return nil
        }
        _ = await manualRefreshTask?.value
        manualRefreshTask = nil
    }

    func performRefreshAction(_ action: FeedRefreshAction) async -> FeedRefreshResult {
        await refresh(intent: action)
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

    func loadChannelVideosPage(
        channelID: String,
        pageToken: String?,
        limit: Int = 50
    ) async -> ChannelVideoPageResult {
        do {
            let page = try await remoteSearchService.refreshChannelVideosPage(
                channelID: channelID,
                pageToken: pageToken,
                limit: limit
            )
            await writeService.saveChannelNextPageToken(page.nextPageToken, channelID: channelID)
            return page
        } catch {
            RuntimeDiagnostics.shared.record(
                "channel_page_load_failed",
                detail: "チャンネル動画のページ取得に失敗",
                metadata: [
                    "channelID": channelID,
                    "pageToken": pageToken ?? "",
                    "limit": String(limit),
                    "reason": RemoteSearchErrorPolicy.diagnosticReason(for: error)
                ]
            )
            return ChannelVideoPageResult(videos: [], totalCount: 0, fetchedAt: .now, nextPageToken: pageToken)
        }
    }

    func loadChannelPlaylists(channelID: String, limit: Int = 50) async -> [PlaylistBrowseItem] {
        await loadChannelPlaylistsInternal(channelID: channelID, limit: limit)
    }

    private func loadChannelPlaylistsInternal(channelID: String, limit: Int = 50) async -> [PlaylistBrowseItem] {
        let normalizedChannelID = channelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedChannelID.isEmpty else { return [] }

        let startedAt = Date()
        do {
            let playlists = try await channelPlaylistBrowseService.loadPlaylists(
                channelID: normalizedChannelID,
                limit: limit
            )
            await writeService.savePlaylistItems(playlists, channelID: normalizedChannelID)
            AppConsoleLogger.appLifecycle.info(
                "channel_playlist_list_complete",
                metadata: [
                    "channelID": normalizedChannelID,
                    "items": String(playlists.count),
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
                ]
            )
            return playlists
        } catch {
            RuntimeDiagnostics.shared.record(
                "channel_playlist_list_failed",
                detail: "チャンネルのプレイリスト一覧取得に失敗",
                metadata: [
                    "channelID": normalizedChannelID,
                    "limit": String(limit),
                    "reason": RemoteSearchErrorPolicy.diagnosticReason(for: error)
                ]
            )
            AppConsoleLogger.appLifecycle.error(
                "channel_playlist_list_failed",
                metadata: [
                    "channelID": normalizedChannelID,
                    "limit": String(limit),
                    "reason": RemoteSearchErrorPolicy.diagnosticReason(for: error)
                ]
            )
            return []
        }
    }

    func loadPlaylistVideosPage(
        playlistID: String,
        pageToken: String?,
        limit: Int = 50
    ) async -> PlaylistBrowseVideosPage {
        await loadPlaylistVideosPageInternal(
            playlistID: playlistID,
            pageToken: pageToken,
            limit: limit
        )
    }

    private func loadPlaylistVideosPageInternal(
        playlistID: String,
        pageToken: String?,
        limit: Int = 50
    ) async -> PlaylistBrowseVideosPage {
        let normalizedPlaylistID = playlistID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPlaylistID.isEmpty else {
            return PlaylistBrowseVideosPage(
                playlistID: playlistID,
                videos: [],
                totalCount: 0,
                fetchedAt: .now,
                nextPageToken: pageToken
            )
        }

        let startedAt = Date()
        do {
            let page = try await channelPlaylistBrowseService.loadPlaylistVideosPage(
                playlistID: normalizedPlaylistID,
                pageToken: pageToken,
                limit: limit
            )
            await writeService.savePlaylistVideosPage(page)
            AppConsoleLogger.appLifecycle.info(
                "playlist_videos_page_complete",
                metadata: [
                    "playlistID": normalizedPlaylistID,
                    "videos": String(page.videos.count),
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
                ]
            )
            return page
        } catch {
            RuntimeDiagnostics.shared.record(
                "playlist_videos_page_failed",
                detail: "プレイリスト内動画のページ取得に失敗",
                metadata: [
                    "playlistID": normalizedPlaylistID,
                    "pageToken": pageToken ?? "",
                    "limit": String(limit),
                    "reason": RemoteSearchErrorPolicy.diagnosticReason(for: error)
                ]
            )
            AppConsoleLogger.appLifecycle.error(
                "playlist_videos_page_failed",
                metadata: [
                    "playlistID": normalizedPlaylistID,
                    "pageToken": pageToken ?? "",
                    "limit": String(limit),
                    "reason": RemoteSearchErrorPolicy.diagnosticReason(for: error)
                ]
            )
            return PlaylistBrowseVideosPage(
                playlistID: normalizedPlaylistID,
                videos: [],
                totalCount: 0,
                fetchedAt: .now,
                nextPageToken: pageToken
            )
        }
    }

    func playlistContinuousPlayURL(playlistID: String) -> URL? {
        playlistContinuousPlayURLInternal(playlistID: playlistID)
    }

    private func playlistContinuousPlayURLInternal(playlistID: String) -> URL? {
        let normalizedPlaylistID = playlistID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPlaylistID.isEmpty else { return nil }
        return channelPlaylistBrowseService.continuousPlayURL(playlistID: normalizedPlaylistID)
    }

    func openChannelVideos(_ context: ChannelVideosRouteContext) async -> [CachedVideo] {
        let channelID = context.channelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !channelID.isEmpty else { return [] }

        let startedAt = Date()
        var mergedVideos = await loadVideosForChannel(channelID)
        guard context.prefersAutomaticRefresh else {
            AppConsoleLogger.appLifecycle.info(
                "channel_videos_open_complete",
                metadata: [
                    "channelID": channelID,
                    "videos": String(mergedVideos.count),
                    "refreshed": "false",
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
                ]
            )
            return mergedVideos
        }

        let shouldRefresh = await shouldAutomaticallyRefreshChannelVideos(context)
        guard shouldRefresh else {
            AppConsoleLogger.appLifecycle.info(
                "channel_videos_open_complete",
                metadata: [
                    "channelID": channelID,
                    "videos": String(mergedVideos.count),
                    "refreshed": "false",
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
                ]
            )
            return mergedVideos
        }

        if case let .channelVideos(refreshedVideos) = await refresh(intent: .channel(context)) {
            mergedVideos = refreshedVideos
        }
        mergedVideos = await loadRemoteSearchChannelFallbackIfNeeded(context: context, currentVideos: mergedVideos)
        AppConsoleLogger.appLifecycle.info(
            "channel_videos_open_complete",
            metadata: [
                "channelID": channelID,
                "videos": String(mergedVideos.count),
                "refreshed": "true",
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
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
        await search(keyword: keyword, limit: limit)
    }

    func search(keyword: String, limit: Int = 20) async -> VideoSearchResult {
        await readService.searchVideos(keyword: keyword, limit: limit)
    }

    func processChannel(
        _ channelID: String,
        states: [String: CachedChannelState],
        forceNetworkFetch: Bool = false
    ) async -> FeedChannelProcessResult {
        if forceNetworkFetch {
            let result = await channelSyncService.performForcedRefresh(
                channelID: channelID,
                state: states[channelID],
                cacheThumbnails: true
            )
            return FeedChannelProcessResult(
                errorMessage: result.errorMessage,
                fetchedVideoCount: result.fetchedVideoCount,
                uncachedVideoCount: result.uncachedVideos.count,
                conditionalCheckAttempted: false,
                networkFetchAttempted: true,
                httpStatusCode: result.httpStatusCode
            )
        }
        return await channelSyncService.processConditionalRefresh(channelID: channelID, state: states[channelID])
    }

    func prioritizedChannelIDs(states: [String: CachedChannelState]) -> [String] {
        FeedOrdering.prioritizedChannelIDs(channels: channels, states: states)
    }

    func dictionaryKeepingLastValue<Value>(_ pairs: [(String, Value)]) -> [String: Value] {
        Dictionary(pairs, uniquingKeysWith: { _, rhs in rhs })
    }

    func dropChannelRefreshTriggerIfRunning(
        _ trigger: String,
        metadata additionalMetadata: [String: String] = [:]
    ) -> Bool {
        guard isChannelRefreshRunning else { return false }
        var metadata = additionalMetadata
        metadata["trigger"] = trigger
        metadata["has_manual_refresh"] = manualRefreshTask != nil ? "true" : "false"
        metadata["has_wall_clock_scheduler"] = automaticRefreshTask != nil ? "true" : "false"
        AppConsoleLogger.appLifecycle.info(
            "channel_refresh_trigger_dropped",
            metadata: metadata
        )
        RuntimeDiagnostics.shared.record(
            "channel_refresh_trigger_dropped",
            detail: "ChannelRefresh 実行中のため新しいトリガーを破棄",
            metadata: metadata
        )
        return true
    }

    func performConsistencyMaintenanceIfNeeded(force: Bool) async -> CacheConsistencyMaintenanceResult? {
        guard force || !channels.isEmpty else { return nil }
        return await writeService.performConsistencyMaintenance(activeChannelIDs: channels, force: force)
    }

    func syncRegisteredChannelsFromStore(reason: String) {
        let storedChannels = ChannelRegistryStore.loadAllChannelIDs()
        guard !storedChannels.isEmpty else {
            logChannelRegistryCoordinatorSync(
                "coordinator_sync_skipped",
                reason: reason,
                storedChannels: storedChannels,
                metadata: ["skip_reason": "store_empty_preserve_coordinator"]
            )
            RuntimeDiagnostics.shared.record(
                "registered_channels_sync_skipped",
                detail: "登録チャンネルの再同期を省略",
                metadata: [
                    "reason": reason,
                    "currentCount": String(channels.count)
                ]
            )
            return
        }

        guard storedChannels != channels else { return }
        logChannelRegistryCoordinatorSync(
            "coordinator_sync_applying",
            reason: reason,
            storedChannels: storedChannels
        )
        channels = storedChannels
        freshnessInterval = TimeInterval(max(channels.count, 1) * 60)
        logChannelRegistryCoordinatorSync(
            "coordinator_sync_applied",
            reason: reason,
            storedChannels: storedChannels
        )
        RuntimeDiagnostics.shared.record(
            "registered_channels_synced",
            detail: "登録チャンネルを永続ストアから再同期",
            metadata: [
                "reason": reason,
                "channelCount": String(channels.count)
            ]
        )
    }

    func refreshHomeSystemStatus(snapshot: FeedCacheSnapshot? = nil, currentProgress: CacheProgress? = nil) async {
        homeSystemStatus = await homeSystemStatusService.loadStatus(
            snapshot: snapshot,
            currentProgress: currentProgress
        )
    }

    private func startChannelRegistrySyncIfNeeded() {
        let logger = AppConsoleLogger.cloudflareSync
        let storedChannels = ChannelRegistryStore.loadAllChannelIDs()
        guard channelRegistrySyncService.isConfigured else {
            logger.info(
                "coordinator_skip",
                metadata: [
                    "coordinator_channels": String(channels.count),
                    "local_fingerprint": AppConsoleLogger.channelIDsFingerprint(storedChannels),
                    "reason": "endpoint_missing",
                    "source": "bootstrap_complete",
                    "store_channels": String(storedChannels.count)
                ]
            )
            return
        }

        let coordinatorChannelCount = channels.count
        let localFingerprint = AppConsoleLogger.channelIDsFingerprint(storedChannels)
        let storeChannelCount = storedChannels.count
        Task(priority: .utility) { [channelRegistrySyncService] in
            let startedAt = Date()
            logger.info(
                "coordinator_task_start",
                metadata: [
                    "coordinator_channels": String(coordinatorChannelCount),
                    "local_fingerprint": localFingerprint,
                    "source": "bootstrap_complete",
                    "store_channels": String(storeChannelCount)
                ]
            )
            do {
                try await channelRegistrySyncService.syncChannelRegistry()
                logger.info(
                    "coordinator_task_complete",
                    metadata: [
                        "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                        "source": "bootstrap_complete"
                    ]
                )
            } catch is CancellationError {
                logger.info(
                    "coordinator_task_cancelled",
                    metadata: [
                        "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                        "source": "bootstrap_complete"
                    ]
                )
            } catch {
                logger.error(
                    "coordinator_task_failed",
                    message: AppConsoleLogger.errorSummary(error),
                    metadata: [
                        "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                        "source": "bootstrap_complete"
                    ]
                )
                RuntimeDiagnostics.shared.record(
                    "channel_registry_sync_failed",
                    detail: "Cloudflare KV 同期に失敗",
                    metadata: [
                        "reason": error.localizedDescription
                    ]
                )
            }
        }
    }
}
