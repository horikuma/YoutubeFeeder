import Foundation

struct YouTubeFeedFetchPipeline {
    let transport: YouTubeFeedTransport
    let videoDetailsClient: YouTubeFeedVideoDetailsClient

    func fetchLatestFeed(for channelID: String) async throws -> (videos: [YouTubeVideo], metadata: FeedFetchMetadata) {
        let startedAt = Date()
        logFeedRequestStarted(channelID: channelID)
        let request = URLRequest(
            url: YouTubeFeedService.feedURL(for: channelID),
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 30
        )
        let (data, response) = try await transport.performScheduledData(for: request)
        let httpResponse = response as? HTTPURLResponse
        logFeedResponseReceived(channelID: channelID, httpResponse: httpResponse, data: data, startedAt: startedAt)
        let metadata = FeedFetchMetadata(
            checkedAt: .now,
            validationToken: FeedValidationToken(
                etag: httpResponse?.value(forHTTPHeaderField: "ETag"),
                lastModified: httpResponse?.value(forHTTPHeaderField: "Last-Modified")
            ),
            httpStatusCode: httpResponse?.statusCode
        )

        let parsedVideos = parseVideos(data: data)
        logFeedParseComplete(channelID: channelID, httpResponse: httpResponse, data: data, parsedVideos: parsedVideos)
        if parsedVideos.isEmpty {
            logFeedZeroVideosDiagnosed(channelID: channelID, httpResponse: httpResponse, data: data, parsedVideos: parsedVideos)
        }

        let videos = if let enrichedVideos = try? await videoDetailsClient.enrich(parsedVideos) {
            enrichedVideos
        } else {
            parsedVideos
        }
        logFeedFetchComplete(channelID: channelID, parsedVideos: parsedVideos.count, returnedVideos: videos.count, startedAt: startedAt)

        return (videos, metadata)
    }

    private func logFeedRequestStarted(channelID: String) {
        AppConsoleLogger.feedRefresh.debug(
            "feed_request_started",
            metadata: [
                "channelID": channelID,
                "method": "GET",
                "validation_mode": "unconditional",
                "playlist_id": YouTubeFeedService.uploadsPlaylistID(for: channelID)
            ]
        )
    }

    private func logFeedResponseReceived(
        channelID: String,
        httpResponse: HTTPURLResponse?,
        data: Data,
        startedAt: Date
    ) {
        AppConsoleLogger.feedRefresh.debug(
            "feed_response_received",
            metadata: YouTubeFeedResponseDiagnostics.responseMetadata(
                channelID: channelID,
                httpResponse: httpResponse,
                data: data,
                elapsedMilliseconds: AppConsoleLogger.elapsedMilliseconds(since: startedAt)
            )
        )
    }

    private func parseVideos(data: Data) -> [YouTubeVideo] {
        YouTubeFeedParser().parse(data: data)
            .sorted { lhs, rhs in
                switch (lhs.publishedAt, rhs.publishedAt) {
                case let (left?, right?):
                    return left > right
                case (_?, nil):
                    return true
                default:
                    return false
                }
            }
    }

    private func logFeedParseComplete(
        channelID: String,
        httpResponse: HTTPURLResponse?,
        data: Data,
        parsedVideos: [YouTubeVideo]
    ) {
        AppConsoleLogger.feedRefresh.debug(
            "feed_parse_complete",
            metadata: YouTubeFeedResponseDiagnostics.parseMetadata(
                channelID: channelID,
                httpResponse: httpResponse,
                data: data,
                parsedVideos: parsedVideos
            )
        )
    }

    private func logFeedZeroVideosDiagnosed(
        channelID: String,
        httpResponse: HTTPURLResponse?,
        data: Data,
        parsedVideos: [YouTubeVideo]
    ) {
        AppConsoleLogger.feedRefresh.debug(
            "feed_zero_videos_diagnosed",
            metadata: YouTubeFeedResponseDiagnostics.parseMetadata(
                channelID: channelID,
                httpResponse: httpResponse,
                data: data,
                parsedVideos: parsedVideos
            )
        )
    }

    private func logFeedFetchComplete(channelID: String, parsedVideos: Int, returnedVideos: Int, startedAt: Date) {
        AppConsoleLogger.feedRefresh.debug(
            "feed_fetch_complete",
            metadata: [
                "channelID": channelID,
                "parsed_videos": String(parsedVideos),
                "returned_videos": String(returnedVideos),
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
            ]
        )
    }
}
