import Foundation

struct FeedChannelForcedRefreshResult {
    let uncachedVideos: [YouTubeVideo]
    let errorMessage: String?
}

struct FeedChannelSyncService {
    let writer: FeedCacheWriteService
    let feedService: YouTubeFeedService

    func processConditionalRefresh(channelID: String, state: CachedChannelState?) async -> String? {
        let token = FeedValidationToken(
            etag: state?.etag,
            lastModified: state?.lastModified
        )

        do {
            let checkResult = try await feedService.checkForUpdates(for: channelID, validationToken: token)
            switch checkResult {
            case let .notModified(metadata):
                await writer.recordNotModified(channelID: channelID, metadata: metadata)
            case .updated:
                let result = try await feedService.fetchLatestFeed(for: channelID)
                _ = await writer.recordSuccessCachingThumbnails(
                    channelID: channelID,
                    videos: result.videos,
                    metadata: result.metadata
                )
            }
            return nil
        } catch {
            let message = error.localizedDescription
            await writer.recordFailure(channelID: channelID, checkedAt: .now, error: message)
            return message
        }
    }

    func performForcedRefresh(channelID: String) async -> FeedChannelForcedRefreshResult {
        do {
            let result = try await feedService.fetchLatestFeed(for: channelID)
            let uncachedVideos = await writer.recordSuccess(channelID: channelID, videos: result.videos, metadata: result.metadata)
            return FeedChannelForcedRefreshResult(uncachedVideos: uncachedVideos, errorMessage: nil)
        } catch {
            let message = error.localizedDescription
            await writer.recordFailure(channelID: channelID, checkedAt: .now, error: message)
            return FeedChannelForcedRefreshResult(uncachedVideos: [], errorMessage: message)
        }
    }
}
