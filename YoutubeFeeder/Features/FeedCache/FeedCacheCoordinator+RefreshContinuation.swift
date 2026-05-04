import Foundation

extension FeedCacheCoordinator {
    func performMockRefresh() async {
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

    func performMockChannelRefresh(channelID: String) async {
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
            lastError: progress.lastError
        )
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        refreshProgress = .idle
    }

    func performManualChannelRefresh(channelID: String) async {
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
            lastError: result.errorMessage
        )
        refreshProgress = .idle
    }

    func beginManualRefreshProgress(totalChannels: Int) {
        refreshProgress = CacheRefreshProgress(
            isRefreshing: true,
            checkStage: RefreshStageProgress(title: "フィード更新確認", completed: 0, total: totalChannels, activeCalls: 0, callsPerSecond: 3),
            fetchStage: .idle(title: "更新チャンネル取得", callsPerSecond: 0),
            thumbnailStage: .idle(title: "サムネイル取得", callsPerSecond: 0)
        )
    }

    func runManualRefreshChannels(
        _ sortedChannels: [String],
        states: [String: CachedChannelState],
        forceNetworkFetch: Bool = false,
        refreshSource: String
    ) async -> FeedRefreshCycleResult {
        var cycleResult = FeedRefreshCycleResult()
        let progressInterval = 50
        let cycleStartedAt = Date()
        updateManualRefreshActiveCalls(completed: 0, totalChannels: sortedChannels.count, activeCalls: sortedChannels.isEmpty ? 0 : 1)

        for (index, channelID) in sortedChannels.enumerated() {
            let result = await self.processChannel(
                channelID,
                states: states,
                forceNetworkFetch: forceNetworkFetch
            )
            cycleResult.record(result)

            let completed = index + 1
            let remaining = sortedChannels.count - completed
            if completed % progressInterval == 0 || completed == sortedChannels.count {
                AppConsoleLogger.appLifecycle.info(
                    "refresh_cycle_progress",
                    metadata: [
                        "refresh_source": refreshSource,
                        "processed_channels": String(completed),
                        "total_channels": String(sortedChannels.count),
                        "conditional_check_attempted_channels": String(cycleResult.conditionalCheckAttemptedChannels),
                        "network_fetch_attempted_channels": String(cycleResult.networkFetchAttemptedChannels),
                        "http_200_channels": String(cycleResult.httpStatusCounts[200, default: 0]),
                        "http_304_channels": String(cycleResult.httpStatusCounts[304, default: 0]),
                        "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: cycleStartedAt),
                        "result_state": "running"
                    ]
                )
            }
            updateManualRefreshActiveCalls(
                completed: completed,
                totalChannels: sortedChannels.count,
                activeCalls: remaining > 0 ? 1 : 0
            )
        }

        return cycleResult
    }

    func updateManualRefreshActiveCalls(completed: Int, totalChannels: Int, activeCalls: Int) {
        refreshProgress.checkStage = RefreshStageProgress(
            title: refreshProgress.checkStage.title,
            completed: completed,
            total: totalChannels,
            activeCalls: activeCalls,
            callsPerSecond: refreshProgress.checkStage.callsPerSecond
        )
    }

    func finishManualRefreshProgress() {
        refreshProgress = CacheRefreshProgress(
            isRefreshing: false,
            checkStage: completedStage(refreshProgress.checkStage),
            fetchStage: completedStage(refreshProgress.fetchStage),
            thumbnailStage: completedStage(refreshProgress.thumbnailStage)
        )
    }

    func applyForcedRefreshSuccess(_ result: FeedChannelForcedRefreshResult, channelID: String) async {
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
        refreshProgress.thumbnailStage = RefreshStageProgress(
            title: refreshProgress.thumbnailStage.title,
            completed: index,
            total: total,
            activeCalls: 1,
            callsPerSecond: refreshProgress.thumbnailStage.callsPerSecond
        )
        await writeService.cacheThumbnail(for: video)
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

    func applyForcedRefreshFailure() {
        refreshProgress.checkStage = completedStage(refreshProgress.checkStage, total: 1)
        refreshProgress.fetchStage = completedStage(refreshProgress.fetchStage, total: 1)
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

    func refreshUI(
        currentChannelID: String?,
        isRunning: Bool,
        lastError: String?,
        includesVideos: Bool = true
    ) async {
        let startedAt = Date()
        logRefreshUIStart(
            currentChannelID: currentChannelID,
            includesVideos: includesVideos
        )
        let refreshState = await readService.loadRefreshState(.init(
            channels: channels,
            freshnessInterval: freshnessInterval,
            videoQuery: videoQuery,
            currentChannelID: currentChannelID,
            isRunning: isRunning,
            lastError: lastError,
            includesVideos: includesVideos
        ))
        let snapshotLoadedAt = Date()
        let nextProgress = refreshState.progress
        let nextMaintenanceItems = refreshState.maintenanceItems

        applyRefreshUIState(
            progress: nextProgress,
            maintenanceItems: nextMaintenanceItems,
            currentChannelID: currentChannelID,
            includesVideos: includesVideos
        )
        await refreshHomeSystemStatus(snapshot: refreshState.snapshot, currentProgress: nextProgress)
        let homeStatusUpdatedAt = Date()

        await writeService.persistBootstrap(progress: progress, maintenanceItems: maintenanceItems)
        let persistedAt = Date()

        if let loadedVideos = refreshState.videos {
            videos = loadedVideos
        }
        AppConsoleLogger.appLifecycle.debug(
            "refresh_ui_complete",
            metadata: refreshUICompletionMetadata(.init(
                currentChannelID: currentChannelID,
                includesVideos: includesVideos,
                progress: nextProgress,
                maintenanceItemCount: nextMaintenanceItems.count,
                loadedVideoCount: refreshState.videos?.count,
                startedAt: startedAt,
                snapshotLoadedAt: snapshotLoadedAt,
                homeStatusUpdatedAt: homeStatusUpdatedAt,
                persistedAt: persistedAt
            ))
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
    }

    private struct RefreshUICompletionMetadataParams {
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

    private func refreshUICompletionMetadata(_ params: RefreshUICompletionMetadataParams) -> [String: String] {
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

    func completeImportedChannelUpdate(channels: [String], importedChannelIDs: [String]) async {
        resetRemoteSearchSnapshotCache()
        self.channels = channels
        freshnessInterval = TimeInterval(max(channels.count, 1) * 60)
        _ = await performConsistencyMaintenanceIfNeeded(force: true)
        await bootstrapMaintenance()

        if !AppLaunchMode.current.usesMockData {
            scheduleImportedChannelRefresh(channelIDs: importedChannelIDs)
        }
    }

    func scheduleImportedChannelRefresh(channelIDs: [String]) {
        guard !channelIDs.isEmpty else { return }
        guard importRefreshTask == nil else { return }

        importRefreshTask = Task {
            await refreshImportedChannels(channelIDs)
            importRefreshTask = nil
        }
    }

    func refreshImportedChannels(_ importedChannelIDs: [String]) async {
        let snapshot = await readService.loadSnapshot()
        let states = dictionaryKeepingLastValue(snapshot.channels.map { ($0.channelID, $0) })
        let cachedVideoChannelIDs = Set(snapshot.videos.map(\.channelID))
        let prioritizedChannelIDs = importedChannelIDs.sorted { lhs, rhs in
            let lhsNeedsWarmup = states[lhs]?.channelTitle == nil || !cachedVideoChannelIDs.contains(lhs)
            let rhsNeedsWarmup = states[rhs]?.channelTitle == nil || !cachedVideoChannelIDs.contains(rhs)
            if lhsNeedsWarmup != rhsNeedsWarmup {
                return lhsNeedsWarmup && !rhsNeedsWarmup
            }
            return lhs < rhs
        }

        for channelID in prioritizedChannelIDs {
            _ = await self.processChannel(channelID, states: states)
        }

        _ = await performConsistencyMaintenanceIfNeeded(force: false)
        await refreshUI(currentChannelID: nil, isRunning: false, lastError: progress.lastError)
    }
}
