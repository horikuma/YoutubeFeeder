import Foundation

struct FeedCacheDependencies {
    let store: FeedCacheStore
    let feedService: YouTubeFeedService
    let channelResolver: YouTubeChannelResolver
    let searchService: YouTubeSearchService
    let remoteSearchCacheStore: RemoteVideoSearchCacheStore
    let channelRegistrySyncService: ChannelRegistryCloudflareSyncService
    let requestScheduler: RequestScheduler? = nil

    nonisolated static func live() -> FeedCacheDependencies {
        FeedCacheDependencies(
            store: FeedCacheStore(),
            feedService: YouTubeFeedService(),
            channelResolver: YouTubeChannelResolver(),
            searchService: YouTubeSearchService(),
            remoteSearchCacheStore: RemoteVideoSearchCacheStore(),
            channelRegistrySyncService: ChannelRegistryCloudflareSyncService()
        )
    }
}
