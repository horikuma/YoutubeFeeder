import Foundation

struct HomeSystemStatusService {
    let store: FeedCacheStore
    let remoteSearchService: RemoteVideoSearchService
    let homeSearchKeyword: String

    func loadStatus(snapshot: FeedCacheSnapshot? = nil, currentProgress: CacheProgress? = nil) async -> HomeSystemStatus {
        let startedAt = Date()
        AppConsoleLogger.appLifecycle.debug(
            "home_status_load_start",
            metadata: ["main_thread": AppConsoleLogger.mainThreadFlag()]
        )
        let resolvedSnapshot: FeedCacheSnapshot
        let snapshotLoadedAt: Date
        if let snapshot {
            resolvedSnapshot = snapshot
            snapshotLoadedAt = Date()
        } else {
            resolvedSnapshot = await store.loadSnapshot()
            snapshotLoadedAt = Date()
        }
        let cacheStatus = await remoteSearchService.status(keyword: homeSearchKeyword)
        let cacheStatusLoadedAt = Date()
        let registeredChannelCount = ChannelRegistryStore.loadAllChannels().count
        let registeredChannelsLoadedAt = Date()
        let thumbnailBytes = await store.totalThumbnailBytes()
        let thumbnailBytesLoadedAt = Date()
        let status = HomeSystemStatus(
            registeredChannelCount: registeredChannelCount,
            cachedVideoCount: resolvedSnapshot.videos.count,
            cachedThumbnailBytes: thumbnailBytes,
            cacheLastUpdatedAt: currentProgress?.lastUpdatedAt ?? (resolvedSnapshot.savedAt == .distantPast ? nil : resolvedSnapshot.savedAt),
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
                "main_thread": AppConsoleLogger.mainThreadFlag(),
            ]
        )
        return status
    }
}
