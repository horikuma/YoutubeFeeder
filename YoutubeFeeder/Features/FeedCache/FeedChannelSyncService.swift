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
        logRefreshDecision(
            channelID: channelID,
            state: state,
            mode: "conditional",
            networkFetchPolicy: "check_then_fetch_if_updated"
        )

        do {
            let checkResult = try await feedService.checkForUpdates(for: channelID, validationToken: token)
            switch checkResult {
            case let .notModified(metadata):
                logConditionalRefreshNotModified(channelID: channelID, metadata: metadata)
                await writer.recordNotModified(channelID: channelID, metadata: metadata)
                return FeedChannelProcessResult(
                    errorMessage: nil,
                    fetchedVideoCount: nil,
                    uncachedVideoCount: 0,
                    conditionalCheckAttempted: true,
                    networkFetchAttempted: false,
                    httpStatusCode: metadata.httpStatusCode
                )
            case .updated:
                let result = try await feedService.fetchLatestFeed(for: channelID)
                logConditionalRefreshUpdated(channelID: channelID, result: result)
                let uncachedVideos = await writer.recordSuccessCachingThumbnails(
                    channelID: channelID,
                    videos: result.videos,
                    metadata: result.metadata
                )
                return FeedChannelProcessResult(
                    errorMessage: nil,
                    fetchedVideoCount: result.videos.count,
                    uncachedVideoCount: uncachedVideos.count,
                    conditionalCheckAttempted: true,
                    networkFetchAttempted: true,
                    httpStatusCode: result.metadata.httpStatusCode
                )
            }
        } catch {
            return await handleRefreshFailure(
                channelID: channelID,
                mode: "conditional",
                conditionalCheckAttempted: true,
                networkFetchAttempted: false,
                error: error
            )
        }
    }

    func performForcedRefresh(
        channelID: String,
        state: CachedChannelState? = nil,
        cacheThumbnails: Bool = false
    ) async -> FeedChannelForcedRefreshResult {
        logRefreshDecision(
            channelID: channelID,
            state: state,
            mode: "forced",
            networkFetchPolicy: "always_fetch_latest_feed"
        )
        do {
            let result = try await feedService.fetchLatestFeed(for: channelID)
            logForcedRefreshFetched(channelID: channelID, result: result)
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
            let result = await handleRefreshFailure(
                channelID: channelID,
                mode: "forced",
                conditionalCheckAttempted: false,
                networkFetchAttempted: true,
                error: error
            )
            return FeedChannelForcedRefreshResult(
                uncachedVideos: [],
                fetchedVideoCount: 0,
                errorMessage: result.errorMessage,
                httpStatusCode: nil
            )
        }
    }

    private func logRefreshDecision(
        channelID: String,
        state: CachedChannelState?,
        mode: String,
        networkFetchPolicy: String
    ) {
        AppConsoleLogger.feedRefresh.debug(
            "channel_refresh_decision",
            metadata: refreshDecisionMetadata(
                channelID: channelID,
                state: state,
                mode: mode,
                networkFetchPolicy: networkFetchPolicy
            )
        )
    }

    private func logConditionalRefreshNotModified(channelID: String, metadata: FeedFetchMetadata) {
        AppConsoleLogger.feedRefresh.debug(
            "conditional_refresh_not_modified",
            metadata: refreshResultMetadata(
                channelID: channelID,
                networkFetch: "false",
                checkedAt: metadata.checkedAt,
                validationToken: metadata.validationToken
            )
        )
    }

    private func logConditionalRefreshUpdated(
        channelID: String,
        result: (videos: [YouTubeVideo], metadata: FeedFetchMetadata)
    ) {
        AppConsoleLogger.feedRefresh.debug(
            "conditional_refresh_updated",
            metadata: refreshResultMetadata(
                channelID: channelID,
                networkFetch: "true",
                checkedAt: result.metadata.checkedAt,
                validationToken: result.metadata.validationToken,
                videoCount: result.videos.count
            )
        )
    }

    private func logForcedRefreshFetched(
        channelID: String,
        result: (videos: [YouTubeVideo], metadata: FeedFetchMetadata)
    ) {
        AppConsoleLogger.feedRefresh.debug(
            "forced_refresh_fetched",
            metadata: refreshResultMetadata(
                channelID: channelID,
                networkFetch: "true",
                checkedAt: result.metadata.checkedAt,
                validationToken: result.metadata.validationToken,
                videoCount: result.videos.count
            )
        )
    }

    private func handleRefreshFailure(
        channelID: String,
        mode: String,
        conditionalCheckAttempted: Bool,
        networkFetchAttempted: Bool,
        error: Error
    ) async -> FeedChannelProcessResult {
        let message = error.localizedDescription
        AppConsoleLogger.feedRefresh.error(
            "channel_refresh_failed",
            metadata: [
                "channelID": channelID,
                "mode": mode,
                "network_fetch": networkFetchAttempted ? "true" : "false",
                "error": AppConsoleLogger.errorSummary(error)
            ]
        )
        await writer.recordFailure(channelID: channelID, checkedAt: .now, error: message)
        return FeedChannelProcessResult(
            errorMessage: message,
            fetchedVideoCount: nil,
            uncachedVideoCount: 0,
            conditionalCheckAttempted: conditionalCheckAttempted,
            networkFetchAttempted: networkFetchAttempted
        )
    }

    private func refreshResultMetadata(
        channelID: String,
        networkFetch: String,
        checkedAt: Date,
        validationToken: FeedValidationToken,
        videoCount: Int? = nil
    ) -> [String: String] {
        var metadata = [
            "channelID": channelID,
            "network_fetch": networkFetch,
            "checked_at": dateMetadata(checkedAt),
            "etag_present": validationToken.etag == nil ? "false" : "true",
            "last_modified_present": validationToken.lastModified == nil ? "false" : "true"
        ]
        if let videoCount {
            metadata["videos"] = String(videoCount)
        }
        return metadata
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
