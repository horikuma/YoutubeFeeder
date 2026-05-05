import Foundation

@MainActor
final class FeedCacheCoordinatorMaintenanceSupport {
    unowned let coordinator: FeedCacheCoordinator

    init(coordinator: FeedCacheCoordinator) {
        self.coordinator = coordinator
    }

    func performConsistencyMaintenanceIfNeeded(force: Bool) async -> CacheConsistencyMaintenanceResult? {
        guard force || !coordinator.channels.isEmpty else { return nil }
        return await coordinator.writeService.performConsistencyMaintenance(activeChannelIDs: coordinator.channels, force: force)
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
                    "currentCount": String(coordinator.channels.count)
                ]
            )
            return
        }

        guard storedChannels != coordinator.channels else { return }
        logChannelRegistryCoordinatorSync(
            "coordinator_sync_applying",
            reason: reason,
            storedChannels: storedChannels
        )
        coordinator.channels = storedChannels
        coordinator.freshnessInterval = TimeInterval(max(coordinator.channels.count, 1) * 60)
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
                "channelCount": String(coordinator.channels.count)
            ]
        )
    }

    func refreshHomeSystemStatus(snapshot: FeedCacheSnapshot? = nil, currentProgress: CacheProgress? = nil) async {
        coordinator.homeSystemStatus = await coordinator.homeSystemStatusService.loadStatus(
            snapshot: snapshot,
            currentProgress: currentProgress
        )
    }

    func startChannelRegistrySyncIfNeeded() {
        let storedChannels = ChannelRegistryStore.loadAllChannelIDs()
        guard coordinator.channelRegistrySyncService.isConfigured else {
            logChannelRegistryCoordinatorSkip(storedChannels: storedChannels)
            return
        }

        let coordinatorChannelCount = coordinator.channels.count
        let localFingerprint = AppConsoleLogger.channelIDsFingerprint(storedChannels)
        let storeChannelCount = storedChannels.count
        Task(priority: .utility) { [channelRegistrySyncService = coordinator.channelRegistrySyncService] in
            await self.runChannelRegistrySyncTask(
                channelRegistrySyncService: channelRegistrySyncService,
                coordinatorChannelCount: coordinatorChannelCount,
                localFingerprint: localFingerprint,
                storeChannelCount: storeChannelCount
            )
        }
    }

    private func logChannelRegistryCoordinatorSkip(storedChannels: [String]) {
        let logger = AppConsoleLogger.cloudflareSync
        logger.info(
            "coordinator_skip",
            metadata: [
                "coordinator_channels": String(coordinator.channels.count),
                "local_fingerprint": AppConsoleLogger.channelIDsFingerprint(storedChannels),
                "reason": "endpoint_missing",
                "source": "bootstrap_complete",
                "store_channels": String(storedChannels.count)
            ]
        )
    }

    private func runChannelRegistrySyncTask(
        channelRegistrySyncService: ChannelRegistryCloudflareSyncService,
        coordinatorChannelCount: Int,
        localFingerprint: String,
        storeChannelCount: Int
    ) async {
        let logger = AppConsoleLogger.cloudflareSync
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

    private func logChannelRegistryCoordinatorSync(
        _ event: String,
        reason: String,
        storedChannels: [String],
        metadata additionalMetadata: [String: String] = [:]
    ) {
        var metadata = additionalMetadata
        metadata["reason"] = reason
        metadata["stored_count"] = String(storedChannels.count)
        metadata["coordinator_count"] = String(coordinator.channels.count)
        metadata["fingerprint"] = AppConsoleLogger.channelIDsFingerprint(storedChannels)
        AppConsoleLogger.appLifecycle.info(event, metadata: metadata)
    }
}
