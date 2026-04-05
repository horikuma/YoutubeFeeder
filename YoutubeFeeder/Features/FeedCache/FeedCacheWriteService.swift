import Foundation

struct FeedCacheWriteService {
    let store: FeedCacheStore

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
}
