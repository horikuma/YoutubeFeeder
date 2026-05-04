import Foundation

struct FeedCacheWriteService {
    let store: FeedCacheStore
    let remoteSearchCacheStore: RemoteVideoSearchCacheStore

    func recordFailure(channelID: String, checkedAt: Date = .now, error: String) async {
        await store.recordFailure(channelID: channelID, checkedAt: checkedAt, error: error)
    }

    func recordNotModified(channelID: String, metadata: FeedFetchMetadata) async {
        await store.recordNotModified(channelID: channelID, metadata: metadata)
    }

    func recordSuccess(channelID: String, videos: [YouTubeVideo], metadata: FeedFetchMetadata) async -> [YouTubeVideo] {
        await store.recordSuccess(channelID: channelID, videos: videos, metadata: metadata)
    }

    func recordSuccessCachingThumbnails(
        channelID: String,
        videos: [YouTubeVideo],
        metadata: FeedFetchMetadata
    ) async -> [YouTubeVideo] {
        let uncachedVideos = await recordSuccess(channelID: channelID, videos: videos, metadata: metadata)
        for video in uncachedVideos where video.thumbnailURL != nil {
            await cacheThumbnail(for: video)
        }
        return uncachedVideos
    }

    func cacheThumbnail(for video: YouTubeVideo) async {
        await store.cacheThumbnail(for: video)
    }

    func cacheThumbnail(for video: CachedVideo) async -> String? {
        await store.cacheThumbnail(for: video)
    }

    func savePlaylistItems(_ items: [PlaylistBrowseItem], channelID: String) async {
        await store.savePlaylistItems(items, channelID: channelID)
    }

    func savePlaylistVideosPage(_ page: PlaylistBrowseVideosPage) async {
        await store.savePlaylistVideosPage(page)
    }

    func saveChannelNextPageToken(_ nextPageToken: String?, channelID: String) async {
        await store.saveChannelNextPageToken(nextPageToken, channelID: channelID)
    }

    func persistBootstrap(progress: CacheProgress, maintenanceItems: [ChannelMaintenanceItem]) async {
        await store.persistBootstrap(progress: progress, maintenanceItems: maintenanceItems)
    }

    func performConsistencyMaintenance(
        activeChannelIDs: [String],
        force: Bool = false
    ) async -> CacheConsistencyMaintenanceResult? {
        await store.performConsistencyMaintenance(activeChannelIDs: activeChannelIDs, force: force)
    }

    func resetAllStoredData() async -> (removedVideoCount: Int, removedThumbnailCount: Int) {
        await store.resetAllStoredData()
    }

    func mergeRemoteSearch(keyword: String, videos: [CachedVideo], fetchedAt: Date) async {
        await remoteSearchCacheStore.merge(keyword: keyword, videos: videos, fetchedAt: fetchedAt)
    }

    func saveRemoteSearch(keyword: String, videos: [CachedVideo], totalCount: Int, fetchedAt: Date) async {
        await remoteSearchCacheStore.save(keyword: keyword, videos: videos, totalCount: totalCount, fetchedAt: fetchedAt)
    }

    func saveRemoteSearchChannelVideos(channelID: String, videos: [CachedVideo], fetchedAt: Date) async {
        await saveRemoteSearch(
            keyword: Self.remoteSearchChannelKeyword(channelID: channelID),
            videos: videos,
            totalCount: videos.count,
            fetchedAt: fetchedAt
        )
    }

    func clearRemoteSearch(keyword: String) async {
        await remoteSearchCacheStore.clear(keyword: keyword)
    }

    func clearAllRemoteSearch() async -> Int {
        await remoteSearchCacheStore.clearAll()
    }

    private static func remoteSearchChannelKeyword(channelID: String) -> String {
        "channel-videos-\(channelID)"
    }
}
