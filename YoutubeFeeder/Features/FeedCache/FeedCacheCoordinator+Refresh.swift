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
        logFullRefreshCycleStarted(refreshSource: refreshSource, snapshot: snapshot, sortedChannels: sortedChannels)
        let cycleResult = await runRefreshCycle(
            channelIDs: sortedChannels,
            states: states,
            forceNetworkFetch: false,
            refreshSource: refreshSource
        )
        logRefreshCycleFinished(
            event: "full_channel_refresh_finished",
            startedAt: startedAt,
            cycleResult: cycleResult,
            channelCount: channels.count,
            targetChannelsCount: sortedChannels.count,
            snapshotChannelCount: snapshot.channels.count,
            refreshSource: refreshSource
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
        logRecentRefreshCycleStarted(refreshSource: refreshSource, snapshot: snapshot, dueChannels: dueChannels)

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
        logRefreshCycleFinished(
            event: "recent_channel_refresh_finished",
            startedAt: startedAt,
            cycleResult: cycleResult,
            channelCount: channels.count,
            targetChannelsCount: dueChannels.count,
            snapshotChannelCount: snapshot.channels.count,
            refreshSource: refreshSource,
            dueChannelsCount: dueChannels.count
        )
    }

    private func logRefreshCycleStart(
        startedEvent: String,
        evaluatedEvent: String,
        evaluationIsDebug: Bool,
        refreshSource: String,
        targetChannelsCount: Int,
        snapshotChannelCount: Int,
        channelCount: Int,
        dueChannelsCount: Int,
        freshnessBypassed: String?,
        forceNetworkFetch: String?,
        snapshotDependency: String?,
        snapshotDependencyDetail: String?,
        channelFingerprint: String?,
        snapshotFingerprint: String?
    ) {
        AppConsoleLogger.appLifecycle.info(
            startedEvent,
            metadata: [
                "refresh_source": refreshSource,
                "target_channels": String(targetChannelsCount),
                "snapshot_channels": String(snapshotChannelCount),
                "channel_count": String(channelCount),
                "result_state": "running"
            ]
        )
        var metadata: [String: String] = [
            "channel_count": String(channelCount),
            "snapshot_channels": String(snapshotChannelCount),
            "due_channels": String(dueChannelsCount),
            "refresh_source": refreshSource
        ]
        if let freshnessBypassed { metadata["freshness_bypassed"] = freshnessBypassed }
        if let forceNetworkFetch { metadata["force_network_fetch"] = forceNetworkFetch }
        if let snapshotDependency { metadata["snapshot_dependency"] = snapshotDependency }
        if let snapshotDependencyDetail { metadata["snapshot_dependency_detail"] = snapshotDependencyDetail }
        if let channelFingerprint { metadata["channel_fingerprint"] = channelFingerprint }
        if let snapshotFingerprint { metadata["snapshot_fingerprint"] = snapshotFingerprint }
        if evaluationIsDebug {
            AppConsoleLogger.appLifecycle.debug(evaluatedEvent, metadata: metadata)
        } else {
            AppConsoleLogger.appLifecycle.info(evaluatedEvent, metadata: metadata)
        }
    }

    private func logFullRefreshCycleStarted(
        refreshSource: String,
        snapshot: FeedCacheSnapshot,
        sortedChannels: [String]
    ) {
        logRefreshCycleStart(
            startedEvent: "full_channel_refresh_started",
            evaluatedEvent: "full_channel_refresh_snapshot_evaluated",
            evaluationIsDebug: false,
            refreshSource: refreshSource,
            targetChannelsCount: sortedChannels.count,
            snapshotChannelCount: snapshot.channels.count,
            channelCount: channels.count,
            dueChannelsCount: sortedChannels.count,
            freshnessBypassed: "true",
            forceNetworkFetch: "false",
            snapshotDependency: "channel_order_only",
            snapshotDependencyDetail: "due channels are derived from registered channel ordering only",
            channelFingerprint: AppConsoleLogger.channelIDsFingerprint(channels),
            snapshotFingerprint: AppConsoleLogger.channelIDsFingerprint(snapshot.channels.map(\.channelID))
        )
    }

    private func logRecentRefreshCycleStarted(
        refreshSource: String,
        snapshot: FeedCacheSnapshot,
        dueChannels: [String]
    ) {
        logRefreshCycleStart(
            startedEvent: "recent_channel_refresh_started",
            evaluatedEvent: "recent_channel_refresh_snapshot_evaluated",
            evaluationIsDebug: true,
            refreshSource: refreshSource,
            targetChannelsCount: dueChannels.count,
            snapshotChannelCount: snapshot.channels.count,
            channelCount: channels.count,
            dueChannelsCount: dueChannels.count,
            freshnessBypassed: nil,
            forceNetworkFetch: nil,
            snapshotDependency: nil,
            snapshotDependencyDetail: nil,
            channelFingerprint: nil,
            snapshotFingerprint: nil
        )
    }

    private func logRefreshCycleFinished(
        event: String,
        startedAt: Date,
        cycleResult: FeedRefreshCycleResult,
        channelCount: Int,
        targetChannelsCount: Int,
        snapshotChannelCount: Int,
        refreshSource: String,
        dueChannelsCount: Int? = nil
    ) {
        var metadata = cycleResult.metadata(
            channelCount: targetChannelsCount,
            forceNetworkFetch: false,
            refreshSource: refreshSource,
            cachedVideosBefore: cycleResult.cachedVideosBefore,
            cachedVideosAfter: cycleResult.cachedVideosAfter
        )
        metadata["target_channels"] = String(targetChannelsCount)
        metadata["snapshot_channels"] = String(snapshotChannelCount)
        metadata["channel_count"] = String(channelCount)
        metadata["elapsed_ms"] = AppConsoleLogger.elapsedMilliseconds(since: startedAt)
        metadata["result_state"] = cycleResult.lastError == nil ? "completed" : "completed_with_errors"
        metadata["conditional_check_attempted_channels"] = String(cycleResult.conditionalCheckAttemptedChannels)
        metadata["network_fetch_attempted_channels"] = String(cycleResult.networkFetchAttemptedChannels)
        if let dueChannelsCount {
            metadata["due_channels"] = String(dueChannelsCount)
        }
        AppConsoleLogger.appLifecycle.info(event, metadata: metadata)
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
}
