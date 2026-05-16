import Foundation

struct RefreshUICompletionMetadataParams {
    let currentChannelID: String?
    let includesVideos: Bool
    let progress: CacheProgress
    let maintenanceItemCount: Int
    let loadedVideoCount: Int?
    let startedAt: Date
    let snapshotLoadedAt: Date
    let homeStatusUpdatedAt: Date
    let persistedAt: Date
}

@MainActor
final class FeedCacheCoordinatorRefreshProgressSupport {
    unowned let coordinator: FeedCacheCoordinator

    init(coordinator: FeedCacheCoordinator) {
        self.coordinator = coordinator
    }

    func beginManualRefreshProgress(totalChannels: Int) {
        coordinator.refreshProgress = CacheRefreshProgress(
            isRefreshing: true,
            checkStage: RefreshStageProgress(title: "フィード更新確認", completed: 0, total: totalChannels, activeCalls: 0, callsPerSecond: 3),
            fetchStage: .idle(title: "更新チャンネル取得", callsPerSecond: 0),
            thumbnailStage: .idle(title: "サムネイル取得", callsPerSecond: 0)
        )
    }

    func updateManualRefreshActiveCalls(completed: Int, totalChannels: Int, activeCalls: Int) {
        coordinator.refreshProgress.checkStage = RefreshStageProgress(
            title: coordinator.refreshProgress.checkStage.title,
            completed: completed,
            total: totalChannels,
            activeCalls: activeCalls,
            callsPerSecond: coordinator.refreshProgress.checkStage.callsPerSecond
        )
    }

    func finishManualRefreshProgress() {
        coordinator.refreshProgress = CacheRefreshProgress(
            isRefreshing: false,
            checkStage: completedStage(coordinator.refreshProgress.checkStage),
            fetchStage: completedStage(coordinator.refreshProgress.fetchStage),
            thumbnailStage: completedStage(coordinator.refreshProgress.thumbnailStage)
        )
    }

    func applyForcedRefreshSuccess(_ result: FeedChannelForcedRefreshResult, channelID: String) async {
        coordinator.refreshProgress.fetchStage = RefreshStageProgress(
            title: coordinator.refreshProgress.fetchStage.title,
            completed: 0,
            total: 1,
            activeCalls: 1,
            callsPerSecond: coordinator.refreshProgress.fetchStage.callsPerSecond
        )
        coordinator.refreshProgress.checkStage = completedStage(coordinator.refreshProgress.checkStage, total: 1)
        coordinator.refreshProgress.fetchStage = completedStage(coordinator.refreshProgress.fetchStage, total: 1)

        let thumbnailTargets = result.uncachedVideos.filter { $0.thumbnailURL != nil }
        coordinator.refreshProgress.thumbnailStage = RefreshStageProgress(
            title: coordinator.refreshProgress.thumbnailStage.title,
            completed: 0,
            total: thumbnailTargets.count,
            activeCalls: 0,
            callsPerSecond: coordinator.refreshProgress.thumbnailStage.callsPerSecond
        )

        for (index, video) in thumbnailTargets.enumerated() {
            await cacheForcedRefreshThumbnail(video, channelID: channelID, index: index, total: thumbnailTargets.count)
        }
    }

    func cacheForcedRefreshThumbnail(_ video: YouTubeVideo, channelID: String, index: Int, total: Int) async {
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
        coordinator.refreshProgress.thumbnailStage = RefreshStageProgress(
            title: coordinator.refreshProgress.thumbnailStage.title,
            completed: index,
            total: total,
            activeCalls: 1,
            callsPerSecond: coordinator.refreshProgress.thumbnailStage.callsPerSecond
        )
        await coordinator.writeService.cacheThumbnail(for: video)
        RuntimeDiagnostics.shared.record(
            "channel_manual_refresh_thumbnail_finished",
            detail: "サムネイル取得を完了",
            metadata: [
                "channelID": channelID,
                "videoID": video.id,
                "index": String(index + 1)
            ]
        )
        coordinator.refreshProgress.thumbnailStage = RefreshStageProgress(
            title: coordinator.refreshProgress.thumbnailStage.title,
            completed: index + 1,
            total: total,
            activeCalls: 0,
            callsPerSecond: coordinator.refreshProgress.thumbnailStage.callsPerSecond
        )
    }

    func applyForcedRefreshFailure() {
        coordinator.refreshProgress.checkStage = completedStage(coordinator.refreshProgress.checkStage, total: 1)
        coordinator.refreshProgress.fetchStage = completedStage(coordinator.refreshProgress.fetchStage, total: 1)
    }

    func completedStage(_ stage: RefreshStageProgress, total: Int? = nil, completed: Int? = nil) -> RefreshStageProgress {
        let resolvedTotal = total ?? stage.total
        return RefreshStageProgress(
            title: stage.title,
            completed: completed ?? resolvedTotal,
            total: resolvedTotal,
            activeCalls: 0,
            callsPerSecond: stage.callsPerSecond
        )
    }

    func logRefreshUIStart(
        currentChannelID: String?,
        includesVideos: Bool
    ) {
        AppConsoleLogger.appLifecycle.debug(
            "refresh_ui_start",
            metadata: [
                "current_channel": currentChannelID ?? "none",
                "includes_videos": includesVideos ? "true" : "false",
                "main_thread": AppConsoleLogger.mainThreadFlag()
            ]
        )
    }

    func applyRefreshUIState(
        progress nextProgress: CacheProgress,
        maintenanceItems nextMaintenanceItems: [ChannelMaintenanceItem],
        currentChannelID: String?,
        includesVideos: Bool
    ) {
        coordinator.progress = nextProgress
        coordinator.maintenanceItems = nextMaintenanceItems
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
    }

    func refreshUICompletionMetadata(_ params: RefreshUICompletionMetadataParams) -> [String: String] {
        [
            "current_channel": params.currentChannelID ?? "none",
            "includes_videos": params.includesVideos ? "true" : "false",
            "cached_channels": String(params.progress.cachedChannels),
            "cached_videos": String(params.progress.cachedVideos),
            "loaded_videos": params.loadedVideoCount.map(String.init) ?? "",
            "maintenance_items": String(params.maintenanceItemCount),
            "snapshot_ms": AppConsoleLogger.elapsedMilliseconds(from: params.startedAt, to: params.snapshotLoadedAt),
            "home_status_ms": AppConsoleLogger.elapsedMilliseconds(from: params.snapshotLoadedAt, to: params.homeStatusUpdatedAt),
            "persist_ms": AppConsoleLogger.elapsedMilliseconds(from: params.homeStatusUpdatedAt, to: params.persistedAt),
            "videos_ms": params.includesVideos ? AppConsoleLogger.elapsedMilliseconds(from: params.persistedAt, to: Date()) : "0",
            "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: params.startedAt),
            "main_thread": AppConsoleLogger.mainThreadFlag()
        ]
    }
}
