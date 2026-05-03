import Foundation

struct FeedCacheDependencies {
    let store: FeedCacheStore
    let feedService: YouTubeFeedService
    let channelResolver: YouTubeChannelResolver
    let searchService: YouTubeSearchService
    let playlistService: YouTubePlaylistService = YouTubePlaylistService()
    let remoteSearchCacheStore: RemoteVideoSearchCacheStore
    let channelRegistrySyncService: ChannelRegistryCloudflareSyncService
    var requestScheduler: RequestScheduler? = nil

    nonisolated static func live() -> FeedCacheDependencies {
        let requestScheduler = RequestScheduler()
        return FeedCacheDependencies(
            store: FeedCacheStore(),
            feedService: YouTubeFeedService(requestScheduler: requestScheduler),
            channelResolver: YouTubeChannelResolver(),
            searchService: YouTubeSearchService(),
            remoteSearchCacheStore: RemoteVideoSearchCacheStore(),
            channelRegistrySyncService: ChannelRegistryCloudflareSyncService(),
            requestScheduler: requestScheduler
        )
    }
}
