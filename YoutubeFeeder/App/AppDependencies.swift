import Foundation

struct FeedCacheDependencies {
    let store: FeedCacheStore
    let feedService: YouTubeFeedService
    let channelResolver: YouTubeChannelResolver
    let searchService: YouTubeSearchService
    let remoteSearchCacheStore: RemoteVideoSearchCacheStore
    let channelRegistrySyncService: ChannelRegistryCloudflareSyncService
    var requestScheduler: RequestScheduler? = nil

    nonisolated static func live() -> FeedCacheDependencies {
        var dependencies = FeedCacheDependencies(
            store: FeedCacheStore(),
            feedService: YouTubeFeedService(),
            channelResolver: YouTubeChannelResolver(),
            searchService: YouTubeSearchService(),
            remoteSearchCacheStore: RemoteVideoSearchCacheStore(),
            channelRegistrySyncService: ChannelRegistryCloudflareSyncService()
        )
        dependencies.requestScheduler = RequestScheduler()
        return dependencies
    }
}
