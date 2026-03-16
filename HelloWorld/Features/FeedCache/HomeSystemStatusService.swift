import Foundation

struct HomeSystemStatusService {
    let store: FeedCacheStore
    let remoteSearchService: RemoteVideoSearchService
    let homeSearchKeyword: String

    func loadStatus(snapshot: FeedCacheSnapshot? = nil, currentProgress: CacheProgress? = nil) async -> HomeSystemStatus {
        let resolvedSnapshot: FeedCacheSnapshot
        if let snapshot {
            resolvedSnapshot = snapshot
        } else {
            resolvedSnapshot = await store.loadSnapshot()
        }
        let cacheStatus = await remoteSearchService.status(keyword: homeSearchKeyword)
        return HomeSystemStatus(
            registeredChannelCount: ChannelRegistryStore.loadAllChannels().count,
            cachedVideoCount: resolvedSnapshot.videos.count,
            cachedThumbnailBytes: await store.totalThumbnailBytes(),
            cacheLastUpdatedAt: currentProgress?.lastUpdatedAt ?? (resolvedSnapshot.savedAt == .distantPast ? nil : resolvedSnapshot.savedAt),
            apiKeyConfigured: remoteSearchService.isConfigured,
            searchCacheStatus: cacheStatus
        )
    }
}
