import Foundation

struct HomeSystemStatusService {
    let store: FeedCacheStore
    let remoteSearchService: RemoteVideoSearchService
    let homeSearchKeyword: String

    func loadStatus(snapshot: FeedCacheSnapshot? = nil, currentProgress: CacheProgress? = nil) async -> HomeSystemStatus {
        let startedAt = Date()
        let resolvedSummary: FeedCacheSummary
        let snapshotLoadedAt: Date
        if let snapshot {
            resolvedSummary = await store.summary(for: snapshot)
            snapshotLoadedAt = Date()
        } else if let summary = await store.loadSummary() {
            resolvedSummary = summary
            snapshotLoadedAt = Date()
        } else {
            let loadedSnapshot = await store.loadSnapshot()
            if let summary = await store.loadSummary() {
                resolvedSummary = summary
            } else {
                resolvedSummary = await store.summary(for: loadedSnapshot)
            }
            snapshotLoadedAt = Date()
        }
        let cacheStatus = await remoteSearchService.status(keyword: homeSearchKeyword)
        let cacheStatusLoadedAt = Date()
        let registeredChannelCount = ChannelRegistryStore.loadAllChannels().count
        let registeredChannelsLoadedAt = Date()
        let thumbnailBytesLoadedAt = Date()
        let status = HomeSystemStatus(
            registeredChannelCount: registeredChannelCount,
            cachedVideoCount: resolvedSummary.cachedVideoCount,
            cachedThumbnailBytes: resolvedSummary.cachedThumbnailBytes,
            cacheLastUpdatedAt: currentProgress?.lastUpdatedAt ?? resolvedSummary.savedAt,
            apiKeyConfigured: remoteSearchService.isConfigured,
            searchCacheStatus: cacheStatus
        )
        AppConsoleLogger.appLifecycle.notice(
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
