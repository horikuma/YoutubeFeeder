import Foundation

extension FeedCacheCoordinator {
    func performManualRefresh() async {
        syncRegisteredChannelsFromStore(reason: "manual_refresh_cycle")
        let snapshot = await readService.loadSnapshot()
        let states = dictionaryKeepingLastValue(snapshot.channels.map { ($0.channelID, $0) })
        let sortedChannels = prioritizedChannelIDs(states: states)
        AppConsoleLogger.appLifecycle.info(
            "manual_refresh_snapshot_evaluated",
            metadata: [
                "channel_count": String(channels.count),
                "snapshot_channels": String(snapshot.channels.count),
                "due_channels": String(sortedChannels.count),
                "freshness_bypassed": "true",
                "force_network_fetch": "true",
                "snapshot_dependency": "ordering_only",
                "channel_fingerprint": AppConsoleLogger.channelIDsFingerprint(channels),
                "snapshot_fingerprint": AppConsoleLogger.channelIDsFingerprint(snapshot.channels.map(\.channelID))
            ]
        )
        _ = await runRefreshCycle(
            channelIDs: sortedChannels,
            states: states,
            forceNetworkFetch: true,
            refreshSource: "manual"
        )
    }

    func startAutomaticRefreshLoopIfNeeded() {
        guard automaticRefreshTask == nil else {
            AppConsoleLogger.appLifecycle.info(
                "auto_refresh_loop_start_skipped",
                metadata: [
                    "reason": "already_running",
                    "has_manual_refresh": manualRefreshTask != nil ? "true" : "false"
                ]
            )
            return
        }
        AppConsoleLogger.appLifecycle.info(
            "auto_refresh_loop_start_requested",
            metadata: [
                "has_manual_refresh": manualRefreshTask != nil ? "true" : "false",
                "channel_count": String(channels.count)
            ]
        )
        automaticRefreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.runAutomaticRefreshLoop()
            self.automaticRefreshTask = nil
        }
    }

    func runAutomaticRefreshLoop() async {
        AppConsoleLogger.appLifecycle.info(
            "auto_refresh_loop_entered",
            metadata: [
                "channel_count": String(channels.count),
                "has_manual_refresh": manualRefreshTask != nil ? "true" : "false"
            ]
        )
        while !Task.isCancelled {
            self.syncRegisteredChannelsFromStore(reason: "automatic_refresh_loop")
            if manualRefreshTask != nil {
                AppConsoleLogger.appLifecycle.info(
                    "auto_refresh_loop_waiting_for_manual_refresh",
                    metadata: [
                        "channel_count": String(channels.count)
                    ]
                )
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                continue
            }

            let snapshot = await readService.loadSnapshot()
            let states = dictionaryKeepingLastValue(snapshot.channels.map { ($0.channelID, $0) })
            let dueChannels = ChannelRefreshSchedulePolicy.prioritizedDueChannelIDs(
                channels: channels,
                states: states
            )
            AppConsoleLogger.appLifecycle.info(
                "auto_refresh_loop_snapshot_evaluated",
                metadata: [
                    "channel_count": String(channels.count),
                    "snapshot_channels": String(snapshot.channels.count),
                    "due_channels": String(dueChannels.count)
                ]
            )

            if !dueChannels.isEmpty {
                AppConsoleLogger.appLifecycle.info(
                    "auto_refresh_loop_dispatching",
                    metadata: [
                        "due_channels": String(dueChannels.count)
                    ]
                )
                await runScheduledRefreshCycle(channelIDs: dueChannels, states: states)
                continue
            }

            guard let delay = ChannelRefreshSchedulePolicy.nextRefreshDelay(channels: channels, states: states) else {
                AppConsoleLogger.appLifecycle.info(
                    "auto_refresh_loop_exiting_no_channels",
                    metadata: [
                        "channel_count": String(channels.count),
                        "snapshot_channels": String(snapshot.channels.count)
                    ]
                )
                return
            }

            if delay > 0 {
                AppConsoleLogger.appLifecycle.info(
                    "auto_refresh_loop_sleeping",
                    metadata: [
                        "delay_ms": String(Int(delay * 1000)),
                        "channel_count": String(channels.count)
                    ]
                )
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } else {
                AppConsoleLogger.appLifecycle.info(
                    "auto_refresh_loop_yielding",
                    metadata: [
                        "channel_count": String(channels.count)
                    ]
                )
                await Task.yield()
            }
        }
        AppConsoleLogger.appLifecycle.info(
            "auto_refresh_loop_exited",
            metadata: [
                "cancelled": Task.isCancelled ? "true" : "false",
                "channel_count": String(channels.count)
            ]
        )
    }

    func runScheduledRefreshCycle(channelIDs: [String], states: [String: CachedChannelState]) async {
        guard manualRefreshTask == nil else { return }
        AppConsoleLogger.appLifecycle.info(
            "scheduled_refresh_started",
            metadata: [
                "channel_count": String(channelIDs.count),
                "refresh_source": "automatic"
            ]
        )
        manualRefreshTask = Task { [channelIDs, states] in
            _ = await runRefreshCycle(
                channelIDs: channelIDs,
                states: states,
                forceNetworkFetch: false,
                refreshSource: "automatic"
            )
        }
        await manualRefreshTask?.value
        manualRefreshTask = nil
        AppConsoleLogger.appLifecycle.info(
            "scheduled_refresh_finished",
            metadata: [
                "channel_count": String(channelIDs.count),
                "refresh_source": "automatic"
            ]
        )
    }

    func runRefreshCycle(
        channelIDs: [String],
        states: [String: CachedChannelState],
        forceNetworkFetch: Bool = false,
        refreshSource: String = "automatic"
    ) async -> String? {
        let beforeVideoCount = await readService.loadSnapshot().videos.count
        AppConsoleLogger.appLifecycle.info(
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
        let cycleResult = await runManualRefreshChannels(
            channelIDs,
            states: states,
            forceNetworkFetch: forceNetworkFetch
        )
        finishManualRefreshProgress()
        _ = await performConsistencyMaintenanceIfNeeded(force: false)
        let lastError = cycleResult.lastError
        await refreshUI(currentChannelID: nil, isRunning: false, lastError: lastError)
        let afterVideoCount = await readService.loadSnapshot().videos.count
        AppConsoleLogger.appLifecycle.info(
            "refresh_cycle_finished",
            metadata: [
                "channel_count": String(channelIDs.count),
                "force_network_fetch": forceNetworkFetch ? "true" : "false",
                "refresh_source": refreshSource,
                "network_fetch_attempted_channels": forceNetworkFetch ? String(channelIDs.count) : "conditional",
                "successful_channels": String(cycleResult.successfulChannels),
                "failed_channels": String(cycleResult.failedChannels),
                "fetch_count_observed_channels": String(cycleResult.observedFetchCountChannels),
                "zero_fetched_channels": String(cycleResult.zeroFetchedChannels),
                "nonzero_fetched_channels": String(cycleResult.nonZeroFetchedChannels),
                "fetched_videos_total": String(cycleResult.fetchedVideosTotal),
                "uncached_videos_total": String(cycleResult.uncachedVideosTotal),
                "cached_videos_before": String(beforeVideoCount),
                "cached_videos_after": String(afterVideoCount),
                "cached_videos_delta": String(afterVideoCount - beforeVideoCount),
                "last_error": lastError ?? ""
            ]
        )
        return lastError
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
        forceNetworkFetch: Bool = false
    ) async -> FeedRefreshCycleResult {
        var cycleResult = FeedRefreshCycleResult()
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
        AppConsoleLogger.appLifecycle.info(
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
        AppConsoleLogger.appLifecycle.info(
            "refresh_ui_start",
            metadata: [
                "current_channel": currentChannelID ?? "none",
                "includes_videos": includesVideos ? "true" : "false",
                "main_thread": AppConsoleLogger.mainThreadFlag(),
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
            "main_thread": AppConsoleLogger.mainThreadFlag(),
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
