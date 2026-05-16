import Foundation

@MainActor
final class FeedCacheCoordinatorSupport {
    unowned let coordinator: FeedCacheCoordinator
    private lazy var maintenanceSupport = FeedCacheCoordinatorMaintenanceBridge(coordinator: coordinator)

    init(coordinator: FeedCacheCoordinator) {
        self.coordinator = coordinator
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

    func prioritizedChannelIDs(states: [String: CachedChannelState]) -> [String] {
        FeedOrdering.prioritizedChannelIDs(channels: coordinator.channels, states: states)
    }

    func dictionaryKeepingLastValue<Value>(_ pairs: [(String, Value)]) -> [String: Value] {
        Dictionary(pairs, uniquingKeysWith: { _, rhs in rhs })
    }

    func dropChannelRefreshTriggerIfRunning(
        _ trigger: String,
        metadata additionalMetadata: [String: String] = [:]
    ) -> Bool {
        guard coordinator.isChannelRefreshRunning else { return false }
        var metadata = additionalMetadata
        metadata["trigger"] = trigger
        metadata["has_manual_refresh"] = coordinator.manualRefreshTask != nil ? "true" : "false"
        metadata["has_wall_clock_scheduler"] = coordinator.automaticRefreshTask != nil ? "true" : "false"
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
        await maintenanceSupport.performConsistencyMaintenanceIfNeeded(force: force)
    }

    func syncRegisteredChannelsFromStore(reason: String) {
        maintenanceSupport.syncRegisteredChannelsFromStore(reason: reason)
    }

    func refreshHomeSystemStatus(snapshot: FeedCacheSnapshot? = nil, currentProgress: CacheProgress? = nil) async {
        await maintenanceSupport.refreshHomeSystemStatus(snapshot: snapshot, currentProgress: currentProgress)
    }

    func startChannelRegistrySyncIfNeeded() {
        maintenanceSupport.startChannelRegistrySyncIfNeeded()
    }
}
