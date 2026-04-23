import Foundation

struct FeedChannelForcedRefreshResult {
    let uncachedVideos: [YouTubeVideo]
    let fetchedVideoCount: Int
    let errorMessage: String?
    let httpStatusCode: Int?
}

struct FeedChannelSyncService {
    let writer: FeedCacheWriteService
    let feedService: YouTubeFeedService

    func processConditionalRefresh(channelID: String, state: CachedChannelState?) async -> FeedChannelProcessResult {
        let token = FeedValidationToken(
            etag: state?.etag,
            lastModified: state?.lastModified
        )
        AppConsoleLogger.feedRefresh.debug(
            "channel_refresh_decision",
            metadata: refreshDecisionMetadata(
                channelID: channelID,
                state: state,
                mode: "conditional",
                networkFetchPolicy: "check_then_fetch_if_updated"
            )
        )

        do {
            let checkResult = try await feedService.checkForUpdates(for: channelID, validationToken: token)
            switch checkResult {
            case let .notModified(metadata):
                AppConsoleLogger.feedRefresh.debug(
                    "conditional_refresh_not_modified",
                    metadata: [
                        "channelID": channelID,
                        "network_fetch": "false",
                        "checked_at": dateMetadata(metadata.checkedAt),
                        "etag_present": metadata.validationToken.etag == nil ? "false" : "true",
                        "last_modified_present": metadata.validationToken.lastModified == nil ? "false" : "true"
                    ]
                )
                await writer.recordNotModified(channelID: channelID, metadata: metadata)
                return FeedChannelProcessResult(
                    errorMessage: nil,
                    fetchedVideoCount: nil,
                    uncachedVideoCount: 0,
                    httpStatusCode: metadata.httpStatusCode
                )
            case .updated:
                let result = try await feedService.fetchLatestFeed(for: channelID)
                AppConsoleLogger.feedRefresh.debug(
                    "conditional_refresh_updated",
                    metadata: [
                        "channelID": channelID,
                        "network_fetch": "true",
                        "videos": String(result.videos.count),
                        "checked_at": dateMetadata(result.metadata.checkedAt),
                        "etag_present": result.metadata.validationToken.etag == nil ? "false" : "true",
                        "last_modified_present": result.metadata.validationToken.lastModified == nil ? "false" : "true"
                    ]
                )
                let uncachedVideos = await writer.recordSuccessCachingThumbnails(
                    channelID: channelID,
                    videos: result.videos,
                    metadata: result.metadata
                )
                return FeedChannelProcessResult(
                    errorMessage: nil,
                    fetchedVideoCount: result.videos.count,
                    uncachedVideoCount: uncachedVideos.count,
                    httpStatusCode: result.metadata.httpStatusCode
                )
            }
        } catch {
            let message = error.localizedDescription
            AppConsoleLogger.feedRefresh.debug(
                "channel_refresh_failed",
                metadata: [
                    "channelID": channelID,
                    "mode": "conditional",
                    "error": AppConsoleLogger.errorSummary(error)
                ]
            )
            await writer.recordFailure(channelID: channelID, checkedAt: .now, error: message)
            return FeedChannelProcessResult(
                errorMessage: message,
                fetchedVideoCount: nil,
                uncachedVideoCount: 0
            )
        }
    }

    func performForcedRefresh(
        channelID: String,
        state: CachedChannelState? = nil,
        cacheThumbnails: Bool = false
    ) async -> FeedChannelForcedRefreshResult {
        AppConsoleLogger.feedRefresh.debug(
            "channel_refresh_decision",
            metadata: refreshDecisionMetadata(
                channelID: channelID,
                state: state,
                mode: "forced",
                networkFetchPolicy: "always_fetch_latest_feed"
            )
        )
        do {
            let result = try await feedService.fetchLatestFeed(for: channelID)
            AppConsoleLogger.feedRefresh.debug(
                "forced_refresh_fetched",
                metadata: [
                    "channelID": channelID,
                    "network_fetch": "true",
                    "videos": String(result.videos.count),
                    "checked_at": dateMetadata(result.metadata.checkedAt),
                    "etag_present": result.metadata.validationToken.etag == nil ? "false" : "true",
                    "last_modified_present": result.metadata.validationToken.lastModified == nil ? "false" : "true"
                ]
            )
            let uncachedVideos = if cacheThumbnails {
                await writer.recordSuccessCachingThumbnails(
                    channelID: channelID,
                    videos: result.videos,
                    metadata: result.metadata
                )
            } else {
                await writer.recordSuccess(
                    channelID: channelID,
                    videos: result.videos,
                    metadata: result.metadata
                )
            }
            return FeedChannelForcedRefreshResult(
                uncachedVideos: uncachedVideos,
                fetchedVideoCount: result.videos.count,
                errorMessage: nil,
                httpStatusCode: result.metadata.httpStatusCode
            )
        } catch {
            let message = error.localizedDescription
            AppConsoleLogger.feedRefresh.error(
                "channel_refresh_failed",
                metadata: [
                    "channelID": channelID,
                    "mode": "forced",
                    "network_fetch": "true",
                    "error": AppConsoleLogger.errorSummary(error)
                ]
            )
            await writer.recordFailure(channelID: channelID, checkedAt: .now, error: message)
            return FeedChannelForcedRefreshResult(
                uncachedVideos: [],
                fetchedVideoCount: 0,
                errorMessage: message,
                httpStatusCode: nil
            )
        }
    }

    private func refreshDecisionMetadata(
        channelID: String,
        state: CachedChannelState?,
        mode: String,
        networkFetchPolicy: String
    ) -> [String: String] {
        [
            "channelID": channelID,
            "mode": mode,
            "network_fetch_policy": networkFetchPolicy,
            "snapshot_state_present": state == nil ? "false" : "true",
            "last_attempt_at": dateMetadata(state?.lastAttemptAt),
            "last_checked_at": dateMetadata(state?.lastCheckedAt),
            "last_success_at": dateMetadata(state?.lastSuccessAt),
            "latest_published_at": dateMetadata(state?.latestPublishedAt),
            "etag_present": state?.etag == nil ? "false" : "true",
            "last_modified_present": state?.lastModified == nil ? "false" : "true"
        ]
    }

    private func dateMetadata(_ date: Date?) -> String {
        guard let date else { return "nil" }
        return String(format: "%.3f", date.timeIntervalSince1970)
    }
}
