import Foundation

@MainActor
final class FeedCacheCoordinatorRefreshWorkflow {
    unowned let coordinator: FeedCacheCoordinator
    private lazy var support = FeedCacheCoordinatorRefreshProgressSupport(coordinator: coordinator)

    init(coordinator: FeedCacheCoordinator) {
        self.coordinator = coordinator
    }

    func beginManualRefreshProgress(totalChannels: Int) {
        support.beginManualRefreshProgress(totalChannels: totalChannels)
    }

    func updateManualRefreshActiveCalls(completed: Int, totalChannels: Int, activeCalls: Int) {
        support.updateManualRefreshActiveCalls(completed: completed, totalChannels: totalChannels, activeCalls: activeCalls)
    }

    func finishManualRefreshProgress() {
        support.finishManualRefreshProgress()
    }

    func processChannel(
        _ channelID: String,
        states: [String: CachedChannelState],
        forceNetworkFetch: Bool = false
    ) async -> FeedChannelProcessResult {
        if forceNetworkFetch {
            let result = await coordinator.channelSyncService.refreshChannelForcingNetworkFetch(
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
        return await coordinator.channelSyncService.processConditionalRefresh(channelID: channelID, state: states[channelID])
    }

    func performMockRefresh() async {
        let totalChannels = max(coordinator.progress.totalChannels, coordinator.maintenanceItems.count)
        coordinator.refreshProgress = CacheRefreshProgress(
            isRefreshing: true,
            checkStage: RefreshStageProgress(title: "フィード更新確認", completed: totalChannels, total: totalChannels, activeCalls: 0, callsPerSecond: 3),
            fetchStage: .idle(title: "更新チャンネル取得", callsPerSecond: 0),
            thumbnailStage: .idle(title: "サムネイル取得", callsPerSecond: 0)
        )
        await refreshUI(currentChannelID: nil, isRunning: false, lastError: coordinator.progress.lastError)
        coordinator.refreshProgress.isRefreshing = false
        _ = await coordinator.performConsistencyMaintenanceIfNeeded(force: false)
    }

    func performMockChannelRefresh(channelID: String) async {
        RuntimeDiagnostics.shared.record(
            "channel_manual_refresh_mock",
            detail: "モック経路でチャンネル更新を処理",
            metadata: ["channelID": channelID]
        )
        coordinator.refreshProgress = CacheRefreshProgress(
            isRefreshing: true,
            checkStage: RefreshStageProgress(title: "チャンネル更新", completed: 0, total: 1, activeCalls: 1, callsPerSecond: 1),
            fetchStage: .idle(title: "更新チャンネル取得", callsPerSecond: 0),
            thumbnailStage: .idle(title: "サムネイル取得", callsPerSecond: 0)
        )
        await refreshUI(
            currentChannelID: channelID,
            isRunning: false,
            lastError: coordinator.progress.lastError
        )
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        coordinator.refreshProgress = .idle
    }

    func performManualChannelRefresh(channelID: String) async {
        let isRegisteredChannel = coordinator.channels.contains(channelID)
        RuntimeDiagnostics.shared.record(
            "channel_manual_refresh_fetch_started",
            detail: "フィード取得を開始",
            metadata: [
                "channelID": channelID,
                "registered": isRegisteredChannel ? "true" : "false"
            ]
        )
        coordinator.refreshProgress = CacheRefreshProgress(
            isRefreshing: true,
            checkStage: RefreshStageProgress(title: "チャンネル更新", completed: 0, total: 1, activeCalls: 1, callsPerSecond: 1),
            fetchStage: RefreshStageProgress(title: "更新チャンネル取得", completed: 0, total: 1, activeCalls: 0, callsPerSecond: 1),
            thumbnailStage: RefreshStageProgress(title: "サムネイル取得", completed: 0, total: 0, activeCalls: 0, callsPerSecond: 1)
        )

        let result = await coordinator.channelSyncService.refreshChannelForcingNetworkFetch(channelID: channelID)
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
            await support.applyForcedRefreshSuccess(result, channelID: channelID)
        } else {
            support.applyForcedRefreshFailure()
        }

        let cleanup = isRegisteredChannel ? await coordinator.performConsistencyMaintenanceIfNeeded(force: false) : nil
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
        coordinator.refreshProgress = .idle
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
        support.updateManualRefreshActiveCalls(completed: 0, totalChannels: sortedChannels.count, activeCalls: sortedChannels.isEmpty ? 0 : 1)

        for (index, channelID) in sortedChannels.enumerated() {
            let result = await processChannel(
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
            support.updateManualRefreshActiveCalls(
                completed: completed,
                totalChannels: sortedChannels.count,
                activeCalls: remaining > 0 ? 1 : 0
            )
        }

        return cycleResult
    }

    func refreshUI(
        currentChannelID: String?,
        isRunning: Bool,
        lastError: String?,
        includesVideos: Bool = true
    ) async {
        let startedAt = Date()
        support.logRefreshUIStart(
            currentChannelID: currentChannelID,
            includesVideos: includesVideos
        )
        let refreshState = await coordinator.readService.loadRefreshState(.init(
            channels: coordinator.channels,
            freshnessInterval: coordinator.freshnessInterval,
            videoQuery: coordinator.videoQuery,
            currentChannelID: currentChannelID,
            isRunning: isRunning,
            lastError: lastError,
            includesVideos: includesVideos
        ))
        let snapshotLoadedAt = Date()
        let nextProgress = refreshState.progress
        let nextMaintenanceItems = refreshState.maintenanceItems

        support.applyRefreshUIState(
            progress: nextProgress,
            maintenanceItems: nextMaintenanceItems,
            currentChannelID: currentChannelID,
            includesVideos: includesVideos
        )
        await coordinator.refreshHomeSystemStatus(snapshot: refreshState.snapshot, currentProgress: nextProgress)
        let homeStatusUpdatedAt = Date()

        await coordinator.writeService.persistBootstrap(progress: coordinator.progress, maintenanceItems: coordinator.maintenanceItems)
        let persistedAt = Date()

        if let loadedVideos = refreshState.videos {
            coordinator.videos = loadedVideos
        }
        AppConsoleLogger.appLifecycle.debug(
            "refresh_ui_complete",
            metadata: support.refreshUICompletionMetadata(.init(
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

    func completeImportedChannelUpdate(channels: [String], importedChannelIDs: [String]) async {
        coordinator.resetRemoteSearchSnapshotCache()
        coordinator.channels = channels
        coordinator.freshnessInterval = TimeInterval(max(channels.count, 1) * 60)
        _ = await coordinator.performConsistencyMaintenanceIfNeeded(force: true)
        await coordinator.bootstrapMaintenance()

        if !AppLaunchMode.current.usesMockData {
            scheduleImportedChannelRefresh(channelIDs: importedChannelIDs)
        }
    }

    func scheduleImportedChannelRefresh(channelIDs: [String]) {
        guard !channelIDs.isEmpty else { return }
        guard coordinator.importRefreshTask == nil else { return }

        coordinator.importRefreshTask = Task {
            await refreshImportedChannels(channelIDs)
            coordinator.importRefreshTask = nil
        }
    }

    func refreshImportedChannels(_ importedChannelIDs: [String]) async {
        let snapshot = await coordinator.readService.loadSnapshot()
        let states = CollectionUtilities.dictionaryKeepingLastValue(snapshot.channels.map { ($0.channelID, $0) })
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
            _ = await processChannel(channelID, states: states)
        }

        _ = await coordinator.performConsistencyMaintenanceIfNeeded(force: false)
        await refreshUI(currentChannelID: nil, isRunning: false, lastError: coordinator.progress.lastError)
    }
}
