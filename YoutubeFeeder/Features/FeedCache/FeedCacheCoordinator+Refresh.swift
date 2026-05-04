import Foundation

extension FeedCacheCoordinator {
    func performManualRefresh() async {
        await performFullChannelRefresh(refreshSource: "manual")
    }

    func performFullChannelRefresh(refreshSource: String = "full") async {
        let startedAt = Date()
        syncRegisteredChannelsFromStore(reason: "manual_refresh_cycle")
        let snapshot = await readService.loadSnapshot()
        let states = dictionaryKeepingLastValue(snapshot.channels.map { ($0.channelID, $0) })
        let sortedChannels = prioritizedChannelIDs(states: states)
        AppConsoleLogger.appLifecycle.info(
            "full_channel_refresh_started",
            metadata: [
                "refresh_source": refreshSource,
                "target_channels": String(sortedChannels.count),
                "snapshot_channels": String(snapshot.channels.count),
                "channel_count": String(channels.count),
                "result_state": "running"
            ]
        )
        AppConsoleLogger.appLifecycle.info(
            "full_channel_refresh_snapshot_evaluated",
            metadata: [
                "channel_count": String(channels.count),
                "snapshot_channels": String(snapshot.channels.count),
                "due_channels": String(sortedChannels.count),
                "freshness_bypassed": "true",
                "force_network_fetch": "false",
                "refresh_source": refreshSource,
                "snapshot_dependency": "channel_order_only",
                "snapshot_dependency_detail": "due channels are derived from registered channel ordering only",
                "channel_fingerprint": AppConsoleLogger.channelIDsFingerprint(channels),
                "snapshot_fingerprint": AppConsoleLogger.channelIDsFingerprint(snapshot.channels.map(\.channelID))
            ]
        )
        let cycleResult = await runRefreshCycle(
            channelIDs: sortedChannels,
            states: states,
            forceNetworkFetch: false,
            refreshSource: refreshSource
        )
        var metadata = cycleResult.metadata(
            channelCount: sortedChannels.count,
            forceNetworkFetch: false,
            refreshSource: refreshSource,
            cachedVideosBefore: cycleResult.cachedVideosBefore,
            cachedVideosAfter: cycleResult.cachedVideosAfter
        )
        metadata["target_channels"] = String(sortedChannels.count)
        metadata["snapshot_channels"] = String(snapshot.channels.count)
        metadata["channel_count"] = String(channels.count)
        metadata["elapsed_ms"] = AppConsoleLogger.elapsedMilliseconds(since: startedAt)
        metadata["result_state"] = cycleResult.lastError == nil ? "completed" : "completed_with_errors"
        metadata["conditional_check_attempted_channels"] = String(cycleResult.conditionalCheckAttemptedChannels)
        metadata["network_fetch_attempted_channels"] = String(cycleResult.networkFetchAttemptedChannels)
        AppConsoleLogger.appLifecycle.info(
            "full_channel_refresh_finished",
            metadata: metadata
        )
    }

    func performRecentChannelRefresh(refreshSource: String = "recent") async {
        let startedAt = Date()
        self.syncRegisteredChannelsFromStore(reason: "recent_channel_refresh")
        let snapshot = await readService.loadSnapshot()
        let states = dictionaryKeepingLastValue(snapshot.channels.map { ($0.channelID, $0) })
        let dueChannels = ChannelRefreshSchedulePolicy.prioritizedDueChannelIDs(
            channels: channels,
            states: states
        )
        AppConsoleLogger.appLifecycle.info(
            "recent_channel_refresh_started",
            metadata: [
                "refresh_source": refreshSource,
                "target_channels": String(dueChannels.count),
                "due_channels": String(dueChannels.count),
                "snapshot_channels": String(snapshot.channels.count),
                "channel_count": String(channels.count),
                "result_state": "running"
            ]
        )
        AppConsoleLogger.appLifecycle.debug(
            "recent_channel_refresh_snapshot_evaluated",
            metadata: [
                "channel_count": String(channels.count),
                "snapshot_channels": String(snapshot.channels.count),
                "due_channels": String(dueChannels.count),
                "refresh_source": refreshSource
            ]
        )

        guard !dueChannels.isEmpty else {
            AppConsoleLogger.appLifecycle.info(
                "recent_channel_refresh_skipped",
                metadata: [
                    "reason": "no_due_channels",
                    "channel_count": String(channels.count),
                    "snapshot_channels": String(snapshot.channels.count),
                    "refresh_source": refreshSource,
                    "target_channels": "0",
                    "due_channels": "0",
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                    "result_state": "skipped"
                ]
            )
            return
        }

        let cycleResult = await runRefreshCycle(
            channelIDs: dueChannels,
            states: states,
            forceNetworkFetch: false,
            refreshSource: refreshSource
        )
        var metadata = cycleResult.metadata(
            channelCount: dueChannels.count,
            forceNetworkFetch: false,
            refreshSource: refreshSource,
            cachedVideosBefore: cycleResult.cachedVideosBefore,
            cachedVideosAfter: cycleResult.cachedVideosAfter
        )
        metadata["target_channels"] = String(dueChannels.count)
        metadata["due_channels"] = String(dueChannels.count)
        metadata["snapshot_channels"] = String(snapshot.channels.count)
        metadata["channel_count"] = String(channels.count)
        metadata["elapsed_ms"] = AppConsoleLogger.elapsedMilliseconds(since: startedAt)
        metadata["result_state"] = cycleResult.lastError == nil ? "completed" : "completed_with_errors"
        metadata["conditional_check_attempted_channels"] = String(cycleResult.conditionalCheckAttemptedChannels)
        metadata["network_fetch_attempted_channels"] = String(cycleResult.networkFetchAttemptedChannels)
        AppConsoleLogger.appLifecycle.info(
            "recent_channel_refresh_finished",
            metadata: metadata
        )
    }

    func startAutomaticRefreshLoopIfNeeded() {
        startChannelRefreshWallClockSchedulerIfNeeded()
    }

    func startChannelRefreshWallClockSchedulerIfNeeded() {
        guard automaticRefreshTask == nil else {
            AppConsoleLogger.appLifecycle.info(
                "channel_refresh_wall_clock_scheduler_start_skipped",
                metadata: [
                    "reason": "already_running",
                    "has_manual_refresh": manualRefreshTask != nil ? "true" : "false",
                    "has_wall_clock_scheduler": automaticRefreshTask != nil ? "true" : "false"
                ]
            )
            return
        }
        AppConsoleLogger.appLifecycle.info(
            "channel_refresh_wall_clock_scheduler_start_requested",
            metadata: [
                "has_manual_refresh": manualRefreshTask != nil ? "true" : "false",
                "has_wall_clock_scheduler": automaticRefreshTask != nil ? "true" : "false",
                "channel_count": String(channels.count)
            ]
        )
        automaticRefreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.runChannelRefreshWallClockScheduler()
            self.automaticRefreshTask = nil
        }
    }

    func runAutomaticRefreshLoop() async {
        AppConsoleLogger.appLifecycle.info(
            "auto_refresh_cycle_entered",
            metadata: [
                "channel_count": String(channels.count),
                "has_manual_refresh": manualRefreshTask != nil ? "true" : "false",
                "has_automatic_refresh": automaticRefreshTask != nil ? "true" : "false"
            ]
        )
        await performRecentChannelRefresh(refreshSource: "automatic")
        AppConsoleLogger.appLifecycle.info(
            "auto_refresh_cycle_exited",
            metadata: [
                "cancelled": Task.isCancelled ? "true" : "false",
                "channel_count": String(channels.count)
            ]
        )
    }

    func runChannelRefreshWallClockScheduler() async {
        let scheduler = ChannelRefreshWallClockScheduler()
        AppConsoleLogger.appLifecycle.info(
            "channel_refresh_wall_clock_scheduler_entered",
            metadata: [
                "channel_count": String(channels.count)
            ]
        )
        while !Task.isCancelled {
            let nextDate = scheduler.nextTriggerDate(after: Date())
            let delay = max(nextDate.timeIntervalSinceNow, 0)
            AppConsoleLogger.appLifecycle.debug(
                "channel_refresh_wall_clock_scheduler_sleeping",
                metadata: [
                    "delay_ms": String(Int(delay * 1000))
                ]
            )
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { break }
            guard let trigger = scheduler.trigger(at: nextDate) else { continue }
            await runWallClockChannelRefresh(trigger)
        }
        AppConsoleLogger.appLifecycle.info(
            "channel_refresh_wall_clock_scheduler_exited",
            metadata: [
                "cancelled": Task.isCancelled ? "true" : "false",
                "channel_count": String(channels.count)
            ]
        )
    }

    func runWallClockChannelRefresh(_ trigger: ChannelRefreshTrigger) async {
        switch trigger {
        case .allChannels:
            await runChannelRefreshExecution(trigger: "wall_clock_all_channels") {
                await self.performFullChannelRefresh(refreshSource: "wall_clock_all_channels")
            }
        case .recentChannels:
            await runChannelRefreshExecution(trigger: "wall_clock_recent_channels") {
                await self.performRecentChannelRefresh(refreshSource: "wall_clock_recent_channels")
            }
        }
    }

    func runChannelRefreshExecution(
        trigger: String,
        operation: @escaping @MainActor () async -> Void
    ) async {
        guard !dropChannelRefreshTriggerIfRunning(trigger) else { return }
        manualRefreshTask = Task { @MainActor in
            await operation()
            return nil
        }
        _ = await manualRefreshTask?.value
        manualRefreshTask = nil
    }

    func runScheduledRefreshCycle(
        channelIDs: [String],
        states: [String: CachedChannelState],
        refreshSource: String = "automatic"
    ) async {
        guard manualRefreshTask == nil else { return }
        let cycleStartedAt = Date()
        AppConsoleLogger.appLifecycle.debug(
            "scheduled_refresh_started",
            metadata: [
                "channel_count": String(channelIDs.count),
                "refresh_source": refreshSource
            ]
        )
        let cycleResult = await runRefreshCycle(
            channelIDs: channelIDs,
            states: states,
            forceNetworkFetch: false,
            refreshSource: refreshSource
        )
        var metadata = cycleResult.metadata(
            channelCount: channelIDs.count,
            forceNetworkFetch: false,
            refreshSource: refreshSource,
            cachedVideosBefore: cycleResult.cachedVideosBefore,
            cachedVideosAfter: cycleResult.cachedVideosAfter
        )
        metadata["elapsed_ms"] = AppConsoleLogger.elapsedMilliseconds(since: cycleStartedAt)
        AppConsoleLogger.appLifecycle.debug(
            "scheduled_refresh_finished",
            metadata: metadata
        )
    }

    func runRefreshTask(
        channelIDs: [String],
        states: [String: CachedChannelState],
        forceNetworkFetch: Bool,
        refreshSource: String
    ) async -> FeedRefreshCycleResult? {
        guard manualRefreshTask == nil else { return nil }
        manualRefreshTask = Task { [channelIDs, states, forceNetworkFetch, refreshSource] in
            let result = await runRefreshCycle(
                channelIDs: channelIDs,
                states: states,
                forceNetworkFetch: forceNetworkFetch,
                refreshSource: refreshSource
            )
            return Optional(result)
        }
        let cycleResult = await manualRefreshTask?.value
        manualRefreshTask = nil
        return cycleResult
    }

    func runRefreshCycle(
        channelIDs: [String],
        states: [String: CachedChannelState],
        forceNetworkFetch: Bool = false,
        refreshSource: String = "automatic"
    ) async -> FeedRefreshCycleResult {
        let beforeVideoCount = await readService.loadSnapshot().videos.count
        AppConsoleLogger.appLifecycle.debug(
            "refresh_cycle_started",
            metadata: [
                "channel_count": String(channelIDs.count),
                "has_manual_refresh": manualRefreshTask != nil ? "true" : "false",
                "force_network_fetch": forceNetworkFetch ? "true" : "false",
                "refresh_source": refreshSource,
                "cached_videos_before": String(beforeVideoCount)
            ]
        )
        beginManualRefreshProgress(totalChannels: channelIDs.count)
        var cycleResult = await runManualRefreshChannels(
            channelIDs,
            states: states,
            forceNetworkFetch: forceNetworkFetch,
            refreshSource: refreshSource
        )
        finishManualRefreshProgress()
        _ = await performConsistencyMaintenanceIfNeeded(force: false)
        let lastError = cycleResult.lastError
        await refreshUI(currentChannelID: nil, isRunning: false, lastError: lastError)
        let afterVideoCount = await readService.loadSnapshot().videos.count
        cycleResult.cachedVideosBefore = beforeVideoCount
        cycleResult.cachedVideosAfter = afterVideoCount
        AppConsoleLogger.appLifecycle.debug(
            "refresh_cycle_finished",
            metadata: cycleResult.metadata(
                channelCount: channelIDs.count,
                forceNetworkFetch: forceNetworkFetch,
                refreshSource: refreshSource,
                cachedVideosBefore: beforeVideoCount,
                cachedVideosAfter: afterVideoCount
            )
        )
        return cycleResult
    }

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
        let refreshState = await readService.loadRefreshState(
            channels: channels,
            freshnessInterval: freshnessInterval,
            videoQuery: videoQuery,
            currentChannelID: currentChannelID,
            isRunning: isRunning,
            lastError: lastError,
            includesVideos: includesVideos
        )
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
            metadata: refreshUICompletionMetadata(
                currentChannelID: currentChannelID,
                includesVideos: includesVideos,
                progress: nextProgress,
                maintenanceItemCount: nextMaintenanceItems.count,
                loadedVideoCount: refreshState.videos?.count,
                startedAt: startedAt,
                snapshotLoadedAt: snapshotLoadedAt,
                homeStatusUpdatedAt: homeStatusUpdatedAt,
                persistedAt: persistedAt
            )
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

    func refreshUICompletionMetadata(
        currentChannelID: String?,
        includesVideos: Bool,
        progress: CacheProgress,
        maintenanceItemCount: Int,
        loadedVideoCount: Int?,
        startedAt: Date,
        snapshotLoadedAt: Date,
        homeStatusUpdatedAt: Date,
        persistedAt: Date
    ) -> [String: String] {
        [
            "current_channel": currentChannelID ?? "none",
            "includes_videos": includesVideos ? "true" : "false",
            "cached_channels": String(progress.cachedChannels),
            "cached_videos": String(progress.cachedVideos),
            "loaded_videos": loadedVideoCount.map(String.init) ?? "",
            "maintenance_items": String(maintenanceItemCount),
            "snapshot_ms": AppConsoleLogger.elapsedMilliseconds(from: startedAt, to: snapshotLoadedAt),
            "home_status_ms": AppConsoleLogger.elapsedMilliseconds(from: snapshotLoadedAt, to: homeStatusUpdatedAt),
            "persist_ms": AppConsoleLogger.elapsedMilliseconds(from: homeStatusUpdatedAt, to: persistedAt),
            "videos_ms": includesVideos ? AppConsoleLogger.elapsedMilliseconds(from: persistedAt, to: Date()) : "0",
            "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
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
