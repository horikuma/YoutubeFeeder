import Foundation

struct HomeSystemStatusService {
    let readService: FeedCacheReadService
    let apiKeyConfigured: Bool
    let homeSearchKeyword: String
    let remoteSearchCacheLifetime: TimeInterval

    func loadStatus(snapshot: FeedCacheSnapshot? = nil, currentProgress: CacheProgress? = nil) async -> HomeSystemStatus {
        let startedAt = Date()
        let resolvedSummary: FeedCacheSummary
        let snapshotLoadedAt: Date
        if let snapshot {
            resolvedSummary = await readService.loadSummary(snapshot: snapshot) ?? .empty
            snapshotLoadedAt = Date()
        } else if let summary = await readService.loadSummary() {
            resolvedSummary = summary
            snapshotLoadedAt = Date()
        } else {
            let loadedSnapshot = await readService.loadSnapshot()
            if let summary = await readService.loadSummary() {
                resolvedSummary = summary
            } else {
                resolvedSummary = await readService.loadSummary(snapshot: loadedSnapshot) ?? .empty
            }
            snapshotLoadedAt = Date()
        }
        let cacheStatus = await readService.loadRemoteSearchStatus(
            keyword: homeSearchKeyword,
            cacheLifetime: remoteSearchCacheLifetime
        )
        let cacheStatusLoadedAt = Date()
        let registeredChannelCount = ChannelRegistryStore.loadAllChannels().count
        let registeredChannelsLoadedAt = Date()
        let thumbnailBytesLoadedAt = Date()
        let status = HomeSystemStatus(
            registeredChannelCount: registeredChannelCount,
            cachedVideoCount: resolvedSummary.cachedVideoCount,
            cachedThumbnailBytes: resolvedSummary.cachedThumbnailBytes,
            cacheLastUpdatedAt: currentProgress?.lastUpdatedAt ?? resolvedSummary.savedAt,
            apiKeyConfigured: apiKeyConfigured,
            searchCacheStatus: cacheStatus
        )
        AppConsoleLogger.appLifecycle.info(
            "home_status_load_complete",
            metadata: [
                "snapshot_ms": AppConsoleLogger.elapsedMilliseconds(from: startedAt, to: snapshotLoadedAt),
                "search_cache_ms": AppConsoleLogger.elapsedMilliseconds(from: snapshotLoadedAt, to: cacheStatusLoadedAt),
                "registry_ms": AppConsoleLogger.elapsedMilliseconds(from: cacheStatusLoadedAt, to: registeredChannelsLoadedAt),
                "thumbnail_ms": AppConsoleLogger.elapsedMilliseconds(from: registeredChannelsLoadedAt, to: thumbnailBytesLoadedAt),
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                "registered_channels": String(status.registeredChannelCount),
                "cached_videos": String(status.cachedVideoCount),
            ]
        )
        return status
    }
}
