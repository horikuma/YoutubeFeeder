import Foundation
import Combine

@MainActor
final class FeedCacheCoordinator: ObservableObject {
    @Published private(set) var progress: CacheProgress
    @Published private(set) var maintenanceItems: [ChannelMaintenanceItem] = []
    @Published private(set) var videos: [CachedVideo] = []
    @Published private(set) var refreshProgress: CacheRefreshProgress = .idle
    @Published private(set) var manualRefreshCount: Int = 0

    private let channels: [String]
    private let store = FeedCacheStore()
    private let feedService = YouTubeFeedService()
    private var manualRefreshTask: Task<Void, Never>?
    private let freshnessInterval: TimeInterval
    private var videoQuery = VideoQuery()
    private var liveUpdateSuspendCount = 0
    private var needsRefreshWhenResumed = false

    init(channels: [String], freshnessInterval: TimeInterval? = nil) {
        self.channels = channels
        self.freshnessInterval = freshnessInterval ?? TimeInterval(max(channels.count, 1) * 60)
        let bootstrap = FeedBootstrapStore.load(channels: channels)
        self.progress = bootstrap.progress
        self.maintenanceItems = bootstrap.maintenanceItems
    }

    func bootstrapMaintenance() async {
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

    func loadChannelBrowseItems() async -> [ChannelBrowseItem] {
        let channelIDs = maintenanceItems.map(\.channelID).isEmpty ? channels : maintenanceItems.map(\.channelID)
        return await store.loadChannelBrowseItems(channelIDs: channelIDs)
    }

    func loadVideosForChannel(_ channelID: String) async -> [CachedVideo] {
        await store.loadVideos(query: VideoQuery(limit: 50, channelID: channelID, keyword: nil, sortOrder: .publishedDescending, excludeShorts: true))
    }

    private func performManualRefresh() async {
        let snapshot = await store.loadSnapshot()
        let states = Dictionary(uniqueKeysWithValues: snapshot.channels.map { ($0.channelID, $0) })
        let sortedChannels = prioritizedChannelIDs(states: states)
        var updatedChannelIDs: [String] = []
        var fetchedVideos: [YouTubeVideo] = []
        var lastError: String?

        refreshProgress = CacheRefreshProgress(
            isRefreshing: true,
            checkStage: RefreshStageProgress(title: "フィード更新確認", completed: 0, total: sortedChannels.count, activeCalls: 0, callsPerSecond: 3),
            fetchStage: RefreshStageProgress(title: "更新チャンネル取得", completed: 0, total: 0, activeCalls: 0, callsPerSecond: 1),
            thumbnailStage: RefreshStageProgress(title: "サムネイル取得", completed: 0, total: 0, activeCalls: 0, callsPerSecond: 1)
        )

        let chunks = stride(from: 0, to: sortedChannels.count, by: 3).map {
            Array(sortedChannels[$0 ..< min($0 + 3, sortedChannels.count)])
        }

        for (chunkIndex, chunk) in chunks.enumerated() {
            refreshProgress.checkStage = RefreshStageProgress(
                title: refreshProgress.checkStage.title,
                completed: refreshProgress.checkStage.completed,
                total: refreshProgress.checkStage.total,
                activeCalls: chunk.count,
                callsPerSecond: refreshProgress.checkStage.callsPerSecond
            )

            await withTaskGroup(of: (String, FeedCheckResult?, String?).self) { group in
                for channelID in chunk {
                    let token = FeedValidationToken(
                        etag: states[channelID]?.etag,
                        lastModified: states[channelID]?.lastModified
                    )
                    group.addTask {
                        do {
                            let result = try await self.feedService.checkForUpdates(for: channelID, validationToken: token)
                            return (channelID, result, nil)
                        } catch {
                            return (channelID, nil, error.localizedDescription)
                        }
                    }
                }

                for await (channelID, result, error) in group {
                    if let error {
                        lastError = error
                        await store.recordFailure(channelID: channelID, checkedAt: .now, error: error)
                    } else if let result {
                        switch result {
                        case let .notModified(metadata):
                            await store.recordNotModified(channelID: channelID, metadata: metadata)
                        case .updated:
                            updatedChannelIDs.append(channelID)
                        }
                    }

                    refreshProgress.checkStage = RefreshStageProgress(
                        title: refreshProgress.checkStage.title,
                        completed: refreshProgress.checkStage.completed + 1,
                        total: refreshProgress.checkStage.total,
                        activeCalls: max(refreshProgress.checkStage.activeCalls - 1, 0),
                        callsPerSecond: refreshProgress.checkStage.callsPerSecond
                    )
                }
            }

            if chunkIndex < chunks.count - 1 {
                try? await Task.sleep(for: .seconds(1))
            }
        }

        refreshProgress.fetchStage = RefreshStageProgress(
            title: refreshProgress.fetchStage.title,
            completed: 0,
            total: updatedChannelIDs.count,
            activeCalls: 0,
            callsPerSecond: refreshProgress.fetchStage.callsPerSecond
        )

        for (index, channelID) in updatedChannelIDs.enumerated() {
            refreshProgress.fetchStage = RefreshStageProgress(
                title: refreshProgress.fetchStage.title,
                completed: index,
                total: refreshProgress.fetchStage.total,
                activeCalls: 1,
                callsPerSecond: refreshProgress.fetchStage.callsPerSecond
            )

            do {
                let result = try await feedService.fetchLatestFeed(for: channelID)
                await store.recordSuccess(channelID: channelID, videos: result.videos, metadata: result.metadata)
                fetchedVideos.append(contentsOf: result.videos)
            } catch {
                lastError = error.localizedDescription
                await store.recordFailure(channelID: channelID, checkedAt: .now, error: error.localizedDescription)
            }

            refreshProgress.fetchStage = RefreshStageProgress(
                title: refreshProgress.fetchStage.title,
                completed: index + 1,
                total: refreshProgress.fetchStage.total,
                activeCalls: 0,
                callsPerSecond: refreshProgress.fetchStage.callsPerSecond
            )

            if index < updatedChannelIDs.count - 1 {
                try? await Task.sleep(for: .seconds(1))
            }
        }

        let thumbnailTargets = fetchedVideos.filter { $0.thumbnailURL != nil }
        refreshProgress.thumbnailStage = RefreshStageProgress(
            title: refreshProgress.thumbnailStage.title,
            completed: 0,
            total: thumbnailTargets.count,
            activeCalls: 0,
            callsPerSecond: refreshProgress.thumbnailStage.callsPerSecond
        )

        for (index, video) in thumbnailTargets.enumerated() {
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

            if index < thumbnailTargets.count - 1 {
                try? await Task.sleep(for: .seconds(1))
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
        await refreshUI(currentChannelID: nil, isRunning: false, lastError: lastError)
    }

    private func performMockRefresh() async {
        let totalChannels = max(progress.totalChannels, maintenanceItems.count)
        refreshProgress = CacheRefreshProgress(
            isRefreshing: true,
            checkStage: RefreshStageProgress(title: "フィード更新確認", completed: totalChannels, total: totalChannels, activeCalls: 0, callsPerSecond: 3),
            fetchStage: RefreshStageProgress(title: "更新チャンネル取得", completed: 0, total: 0, activeCalls: 0, callsPerSecond: 1),
            thumbnailStage: RefreshStageProgress(title: "サムネイル取得", completed: 0, total: 0, activeCalls: 0, callsPerSecond: 1)
        )
        await refreshUI(currentChannelID: nil, isRunning: false, lastError: progress.lastError)
        refreshProgress.isRefreshing = false
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
}
