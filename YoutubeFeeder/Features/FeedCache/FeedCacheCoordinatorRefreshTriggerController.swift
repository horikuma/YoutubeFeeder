import Foundation

@MainActor
final class FeedCacheCoordinatorRefreshTriggerController {
    unowned let coordinator: FeedCacheCoordinator

    init(coordinator: FeedCacheCoordinator) {
        self.coordinator = coordinator
    }

    func bootstrapMaintenance() async {
        let startedAt = Date()
        coordinator.syncRegisteredChannelsFromStore(reason: "bootstrap")
        coordinator.freshnessInterval = TimeInterval(max(coordinator.channels.count, 1) * 60)
        _ = await coordinator.performConsistencyMaintenanceIfNeeded(force: false)
        let bootstrap = FeedBootstrapStore.load(channels: coordinator.channels)
        coordinator.progress = bootstrap.progress
        coordinator.maintenanceItems = bootstrap.maintenanceItems
        await coordinator.refreshHomeSystemStatus()
        coordinator.startChannelRegistrySyncIfNeeded()
        AppConsoleLogger.appLifecycle.info(
            "bootstrap_coordinator_complete",
            metadata: [
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                "channels": String(coordinator.channels.count),
                "maintenance_items": String(coordinator.maintenanceItems.count)
            ]
        )
    }

    func refreshCacheManually() async {
        guard !coordinator.dropChannelRefreshTriggerIfRunning("manual_home_refresh") else { return }
        coordinator.syncRegisteredChannelsFromStore(reason: "manual_refresh")

        AppConsoleLogger.appLifecycle.info(
            "refresh_cache_manual_started",
            metadata: [
                "channels": String(coordinator.channels.count),
                "current_channel": coordinator.progress.currentChannelID ?? "",
                "is_running": coordinator.progress.isRunning ? "true" : "false"
            ]
        )
        coordinator.manualRefreshTask = Task {
            StartupDiagnostics.shared.mark("manualRefreshStarted")
            coordinator.manualRefreshCount += 1
            if AppLaunchMode.current.usesMockData {
                await coordinator.refreshContinuation.performMockRefresh()
            } else {
                await coordinator.performManualRefresh()
            }
            StartupDiagnostics.shared.mark("manualRefreshFinished")
            return nil
        }
        _ = await coordinator.manualRefreshTask?.value
        coordinator.manualRefreshTask = nil
        AppConsoleLogger.appLifecycle.info(
            "refresh_cache_manual_finished",
            metadata: [
                "channels": String(coordinator.channels.count),
                "current_channel": coordinator.progress.currentChannelID ?? "",
                "is_running": coordinator.progress.isRunning ? "true" : "false"
            ]
        )
    }

    func refreshChannelManually(_ channelID: String) async {
        coordinator.syncRegisteredChannelsFromStore(reason: "channel_refresh")
        let normalizedChannelID = channelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedChannelID.isEmpty else {
            RuntimeDiagnostics.shared.record("channel_manual_refresh_ignored", detail: "空の channelID のため更新しない")
            return
        }
        guard !coordinator.dropChannelRefreshTriggerIfRunning(
            "manual_channel_refresh",
            metadata: ["channelID": normalizedChannelID]
        ) else { return }

        let startedAt = Date()
        coordinator.manualRefreshTask = Task {
            await self.runChannelManualRefreshTask(channelID: normalizedChannelID, startedAt: startedAt)
        }
        _ = await coordinator.manualRefreshTask?.value
        coordinator.manualRefreshTask = nil
    }

    private func runChannelManualRefreshTask(channelID: String, startedAt: Date) async -> FeedRefreshCycleResult? {
        StartupDiagnostics.shared.mark("channelManualRefreshStarted")
        AppConsoleLogger.appLifecycle.info(
            "channel_manual_refresh_started",
            metadata: [
                "channelID": channelID,
                "result_state": "running"
            ]
        )
        RuntimeDiagnostics.shared.record(
            "channel_manual_refresh_started",
            detail: "チャンネル単独更新を開始",
            metadata: [
                "channelID": channelID
            ]
        )
        coordinator.lastManualChannelRefreshID = channelID
        if AppLaunchMode.current.usesMockData {
            await coordinator.refreshContinuation.performMockChannelRefresh(channelID: channelID)
        } else {
            await coordinator.refreshContinuation.performManualChannelRefresh(channelID: channelID)
        }
        StartupDiagnostics.shared.mark("channelManualRefreshFinished")
        let updatedItem = coordinator.maintenanceItems.first(where: { $0.channelID == channelID })
        AppConsoleLogger.appLifecycle.info(
            "channel_manual_refresh_finished",
            metadata: [
                "channelID": channelID,
                "result_state": coordinator.progress.lastError == nil ? "completed" : "completed_with_errors",
                "lastError": coordinator.progress.lastError ?? "",
                "cachedVideoCount": String(updatedItem?.cachedVideoCount ?? 0),
                "latestPublishedAt": updatedItem?.latestPublishedAt?.formatted(date: .numeric, time: .standard) ?? "",
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
            ]
        )
        RuntimeDiagnostics.shared.record(
            "channel_manual_refresh_finished",
            detail: "チャンネル単独更新を完了",
            metadata: [
                "channelID": channelID,
                "lastError": coordinator.progress.lastError ?? "",
                "cachedVideoCount": String(updatedItem?.cachedVideoCount ?? 0),
                "latestPublishedAt": updatedItem?.latestPublishedAt?.formatted(date: .numeric, time: .standard) ?? ""
            ]
        )
        return nil
    }
}
