import Foundation

struct YouTubePlaylistService {
    nonisolated static let videoDetailsPartParameter = "snippet,contentDetails,statistics,liveStreamingDetails"

    let dataLoader: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    init(
        dataLoader: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse) = { request in
            try await URLSession.shared.data(for: request)
        }
    ) {
        self.dataLoader = dataLoader
    }

    var isConfigured: Bool {
        AppLaunchMode.current.usesMockData || resolvedAPIKey != nil
    }

    func fetchPlaylists(channelID: String, limit: Int = 50) async throws -> [YouTubePlaylistListItem] {
        let logger = AppConsoleLogger.youtubeSearch
        let startedAt = Date()
        var stage = "prepare"

        do {
            if AppLaunchMode.current.usesMockData {
                stage = "mock_response"
                let response = mockPlaylistsResponse(channelID: channelID, limit: limit)
                logger.info(
                    "playlist_list_request_complete",
                    metadata: [
                        "channelID": channelID,
                        "items": String(response.count),
                        "source": "mock",
                        "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                    ]
                )
                return response
            }

            let apiKey = try resolveAPIKey(channelID: channelID, logger: logger)
            stage = "playlist_list"
            let response = try await fetchPlaylistsResponse(channelID: channelID, apiKey: apiKey, limit: limit)
            let playlists = response.items.map { item in
                YouTubePlaylistListItem(
                    id: item.id,
                    channelID: item.snippet.channelID,
                    channelTitle: item.snippet.channelTitle,
                    title: item.snippet.title,
                    description: item.snippet.description,
                    publishedAt: item.snippet.publishedAt,
                    itemCount: item.contentDetails?.itemCount,
                    thumbnailURL: preferredThumbnailURL(from: item.snippet.thumbnails)
                )
            }
            logger.info(
                "playlist_list_request_complete",
                metadata: [
                    "channelID": channelID,
                    "items": String(playlists.count),
                    "total_results": String(response.pageInfo?.totalResults ?? playlists.count),
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                ]
            )
            return playlists
        } catch {
            handleFailure(
                error,
                stage: stage,
                channelID: channelID,
                startedAt: startedAt,
                logger: logger
            )
            throw error
        }
    }

    func fetchPlaylistVideosPage(
        playlistID: String,
        pageToken: String?,
        limit: Int = 50
    ) async throws -> YouTubePlaylistVideosPage {
        let logger = AppConsoleLogger.youtubeSearch
        let startedAt = Date()
        var stage = "prepare"

        do {
            if AppLaunchMode.current.usesMockData {
                stage = "mock_response"
                let response = mockPlaylistVideosPage(playlistID: playlistID, limit: limit)
                logger.info(
                    "playlist_videos_request_complete",
                    metadata: [
                        "playlist_id": playlistID,
                        "videos": String(response.videos.count),
                        "source": "mock",
                        "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                    ]
                )
                return response
            }

            let apiKey = try resolveAPIKey(channelID: playlistID, logger: logger)
            stage = "playlist_items"
            let response = try await fetchPlaylistVideosPage(
                playlistID: playlistID,
                pageToken: pageToken,
                apiKey: apiKey,
                limit: limit
            )
            logger.info(
                "playlist_videos_request_complete",
                metadata: [
                    "playlist_id": playlistID,
                    "videos": String(response.videos.count),
                    "next_page_token": response.nextPageToken ?? "",
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                ]
            )
            return response
        } catch {
            handleFailure(
                error,
                stage: stage,
                channelID: playlistID,
                startedAt: startedAt,
                logger: logger
            )
            throw error
        }
    }

    func continuousPlayURL(playlistID: String) -> URL? {
        URL(string: "https://www.youtube.com/playlist?list=\(playlistID)")
    }

    private func mockPlaylistsResponse(channelID: String, limit: Int) -> [YouTubePlaylistListItem] {
        let playlists = [
            YouTubePlaylistListItem(
                id: "\(channelID)-playlist-001",
                channelID: channelID,
                channelTitle: "Channel \(channelID)",
                title: "Playlist 1",
                description: "Mock playlist 1",
                publishedAt: .now.addingTimeInterval(-3_600),
                itemCount: 12,
                thumbnailURL: URL(string: "https://example.com/\(channelID)-playlist-001.jpg")
            ),
            YouTubePlaylistListItem(
                id: "\(channelID)-playlist-002",
                channelID: channelID,
                channelTitle: "Channel \(channelID)",
                title: "Playlist 2",
                description: "Mock playlist 2",
                publishedAt: .now.addingTimeInterval(-7_200),
                itemCount: 24,
                thumbnailURL: URL(string: "https://example.com/\(channelID)-playlist-002.jpg")
            ),
            YouTubePlaylistListItem(
                id: "\(channelID)-playlist-003",
                channelID: channelID,
                channelTitle: "Channel \(channelID)",
                title: "Playlist 3",
                description: "Mock playlist 3",
                publishedAt: .now.addingTimeInterval(-10_800),
                itemCount: 6,
                thumbnailURL: URL(string: "https://example.com/\(channelID)-playlist-003.jpg")
            )
        ]
        return Array(playlists.prefix(max(0, limit)))
    }

    private func mockPlaylistVideosPage(playlistID: String, limit: Int) -> YouTubePlaylistVideosPage {
        let videos = (1 ... 12).map { index in
            YouTubePlaylistVideo(
                id: "\(playlistID)-video-\(index)",
                channelID: "UC_MOCK_PLAYLIST",
                channelTitle: "Mock Playlist Channel",
                title: "Playlist video \(index)",
                publishedAt: .now.addingTimeInterval(TimeInterval(-index * 900)),
                videoURL: URL(string: "https://www.youtube.com/watch?v=\(playlistID)-video-\(index)"),
                thumbnailURL: URL(string: "https://example.com/\(playlistID)-video-\(index).jpg"),
                durationSeconds: 900 + index,
                viewCount: 1_000 + index
            )
        }
        return YouTubePlaylistVideosPage(
            playlistID: playlistID,
            videos: Array(videos.prefix(max(0, limit))),
            totalCount: videos.count,
            fetchedAt: .now,
            nextPageToken: nil
        )
    }

    private func fetchPlaylistsResponse(
        channelID: String,
        apiKey: String,
        limit: Int
    ) async throws -> PlaylistsListResponse {
        let startedAt = Date()
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/playlists")
        components?.queryItems = [
            URLQueryItem(name: "part", value: "snippet,contentDetails"),
            URLQueryItem(name: "channelId", value: channelID),
            URLQueryItem(name: "maxResults", value: String(max(1, min(limit, 50)))),
        ]

        guard let url = components?.url else {
            throw YouTubeSearchError.invalidResponse
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")

        let data = try await loadData(
            for: request,
            endpoint: "playlists",
            metadata: [
                "channel_id": channelID,
                "max_results": String(max(1, min(limit, 50))),
            ]
        )
        let response = try decodeResponse(
            PlaylistsListResponse.self,
            from: data,
            endpoint: "playlists",
            metadata: [
                "channel_id": channelID,
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
            ]
        )
        return response
    }

    private func fetchPlaylistVideosPage(
        playlistID: String,
        pageToken: String?,
        apiKey: String,
        limit: Int
    ) async throws -> YouTubePlaylistVideosPage {
        let startedAt = Date()
        let playlistItems = try await fetchPlaylistItems(
            playlistID: playlistID,
            pageToken: pageToken,
            apiKey: apiKey,
            maxResults: limit
        )
        let videoIDs = playlistItems.items.compactMap(\.contentDetails?.videoID)
        let detailedVideos = try await fetchVideoDetails(videoIDs: videoIDs, apiKey: apiKey)
        let videos = Self.mergeVideos(detailedVideos, preferredOrder: videoIDs)
            .filter {
                !ShortVideoMaskPolicy.shouldMask(
                    durationSeconds: $0.durationSeconds,
                    videoURL: $0.videoURL,
                    title: $0.title
                )
            }
        return YouTubePlaylistVideosPage(
            playlistID: playlistID,
            videos: videos,
            totalCount: playlistItems.pageInfo?.totalResults ?? videos.count,
            fetchedAt: .now,
            nextPageToken: playlistItems.nextPageToken
        )
    }

    private func fetchPlaylistItems(
        playlistID: String,
        pageToken: String?,
        apiKey: String,
        maxResults: Int
    ) async throws -> PlaylistItemsListResponse {
        let startedAt = Date()
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/playlistItems")
        var queryItems = [
            URLQueryItem(name: "part", value: "contentDetails"),
            URLQueryItem(name: "playlistId", value: playlistID),
            URLQueryItem(name: "maxResults", value: String(max(1, min(maxResults, 50)))),
        ]
        if let pageToken, !pageToken.isEmpty {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw YouTubeSearchError.invalidResponse
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")

        let data = try await loadData(
            for: request,
            endpoint: "playlistItems",
            metadata: [
                "playlist_id": playlistID,
                "page_token": pageToken ?? "",
                "max_results": String(max(1, min(maxResults, 50))),
            ]
        )
        let response = try decodeResponse(
            PlaylistItemsListResponse.self,
            from: data,
            endpoint: "playlistItems",
            metadata: ["playlist_id": playlistID, "page_token": pageToken ?? ""]
        )
        _ = startedAt
        return response
    }

    private func fetchVideoDetails(videoIDs: [String], apiKey: String) async throws -> [YouTubePlaylistVideo] {
        guard !videoIDs.isEmpty else { return [] }

        let batches = chunkVideoIDs(videoIDs, size: 50)
        var mergedVideos: [YouTubePlaylistVideo] = []

        for batch in batches {
            var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/videos")
            components?.queryItems = [
                URLQueryItem(name: "part", value: Self.videoDetailsPartParameter),
                URLQueryItem(name: "id", value: batch.joined(separator: ",")),
                URLQueryItem(name: "maxResults", value: String(batch.count)),
            ]

            guard let url = components?.url else {
                throw YouTubeSearchError.invalidResponse
            }

            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
            request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")

            let data = try await loadData(
                for: request,
                endpoint: "videos",
                metadata: ["batch": "\(mergedVideos.count + 1)/\(batches.count)", "ids": String(batch.count)]
            )
            let response = try decodeResponse(
                VideoListResponse.self,
                from: data,
                endpoint: "videos",
                metadata: ["batch": "\(mergedVideos.count + 1)/\(batches.count)"]
            )
            let videos = Self.filterPlayableVideos(response.items)
            mergedVideos.append(contentsOf: videos)
        }

        return mergedVideos
    }

    private func resolveAPIKey(channelID: String, logger: AppConsoleLogger) throws -> String {
        guard let apiKey = resolvedAPIKey else {
            logger.error(
                "config_missing",
                message: YouTubeSearchError.apiKeyMissing.localizedDescription,
                metadata: ["channelID": channelID]
            )
            throw YouTubeSearchError.apiKeyMissing
        }
        return apiKey
    }

    private func handleFailure(
        _ error: Error,
        stage: String,
        channelID: String,
        startedAt: Date,
        logger: AppConsoleLogger
    ) {
        let metadata = [
            "channelID": channelID,
            "stage": stage,
            "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
            "reason": RemoteSearchErrorPolicy.diagnosticReason(for: error),
        ]
        if RemoteSearchErrorPolicy.isCancellation(error) {
            logger.info("request_cancelled", metadata: metadata)
        } else {
            logger.error(
                "request_failed",
                message: AppConsoleLogger.errorSummary(error),
                metadata: metadata
            )
        }
    }

    private var resolvedAPIKey: String? {
        let environmentKey = ProcessInfo.processInfo.environment["YOUTUBEFEEDER_YOUTUBE_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let environmentKey, !environmentKey.isEmpty {
            return environmentKey
        }

        let plistKey = Bundle.main.object(forInfoDictionaryKey: "YouTubeAPIKey") as? String
        if let plistKey {
            let trimmed = plistKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, !trimmed.hasPrefix("$(") {
                return trimmed
            }
        }

        return nil
    }

    private func loadData(
        for request: URLRequest,
        endpoint: String,
        metadata: [String: String]
    ) async throws -> Data {
        let startedAt = Date()
        let logger = AppConsoleLogger.youtubeSearch
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await dataLoader(request)
        } catch {
            logTransportFailure(
                error,
                metadata: transportFailureMetadata(metadata, endpoint: endpoint, startedAt: startedAt, error: error),
                logger: logger
            )
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("response_invalid", message: "HTTP response を取得できませんでした。", metadata: invalidResponseMetadata(
                metadata,
                endpoint: endpoint,
                startedAt: startedAt
            ))
            throw YouTubeSearchError.invalidResponse
        }

        let responseMetadata = successMetadata(
            metadata,
            endpoint: endpoint,
            startedAt: startedAt,
            response: httpResponse,
            data: data
        )

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            logger.error(
                "http_failure",
                message: "YouTube API が失敗しました。",
                metadata: responseMetadata.merging(
                    ["body_preview": AppConsoleLogger.responsePreview(data)],
                    uniquingKeysWith: { _, new in new }
                )
            )
            throw YouTubeSearchError.httpError(statusCode: httpResponse.statusCode)
        }

        logger.info("http_success", metadata: responseMetadata)
        return data
    }

    private func decodeResponse<Response: Decodable>(
        _ type: Response.Type,
        from data: Data,
        endpoint: String,
        metadata: [String: String]
    ) throws -> Response {
        do {
            return try JSONDecoder.youtubeAPI.decode(type, from: data)
        } catch {
            let decodeMetadata = metadata.merging(
                ["endpoint": endpoint, "body_preview": AppConsoleLogger.responsePreview(data)],
                uniquingKeysWith: { _, new in new }
            )
            AppConsoleLogger.youtubeSearch.error(
                "decode_failure",
                message: AppConsoleLogger.errorSummary(error),
                metadata: decodeMetadata
            )
            throw error
        }
    }

    private func transportFailureMetadata(
        _ metadata: [String: String],
        endpoint: String,
        startedAt: Date,
        error: Error
    ) -> [String: String] {
        metadata.merging(
            [
                "endpoint": endpoint,
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                "reason": RemoteSearchErrorPolicy.diagnosticReason(for: error),
            ],
            uniquingKeysWith: { _, new in new }
        )
    }

    private func logTransportFailure(
        _ error: Error,
        metadata: [String: String],
        logger: AppConsoleLogger
    ) {
        if RemoteSearchErrorPolicy.isCancellation(error) {
            logger.info("http_cancelled", metadata: metadata)
        } else {
            logger.error(
                "http_transport_failure",
                message: AppConsoleLogger.errorSummary(error),
                metadata: metadata
            )
        }
    }

    private func invalidResponseMetadata(
        _ metadata: [String: String],
        endpoint: String,
        startedAt: Date
    ) -> [String: String] {
        metadata.merging(
            ["endpoint": endpoint, "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)],
            uniquingKeysWith: { _, new in new }
        )
    }

    private func successMetadata(
        _ metadata: [String: String],
        endpoint: String,
        startedAt: Date,
        response: HTTPURLResponse,
        data: Data
    ) -> [String: String] {
        metadata.merging(
            [
                "endpoint": endpoint,
                "status": String(response.statusCode),
                "bytes": String(data.count),
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
            ]
        ) { _, new in new }
    }

    private func chunkVideoIDs(_ videoIDs: [String], size: Int) -> [[String]] {
        guard size > 0 else { return [videoIDs] }
        var result: [[String]] = []
        var index = 0
        while index < videoIDs.count {
            let nextIndex = min(index + size, videoIDs.count)
            result.append(Array(videoIDs[index ..< nextIndex]))
            index = nextIndex
        }
        return result
    }

    private func preferredThumbnailURL(from thumbnails: VideoThumbnails) -> URL? {
        thumbnails.medium?.url ?? thumbnails.high?.url ?? thumbnails.defaultThumbnail?.url
    }
}

private extension YouTubePlaylistService {
    static func filterPlayableVideos(_ items: [VideoListResponse.Item]) -> [YouTubePlaylistVideo] {
        items.compactMap { item in
            guard item.snippet.liveBroadcastContent == "none" else { return nil }
            guard item.liveStreamingDetails == nil else { return nil }
            guard let duration = item.contentDetails?.duration else { return nil }
            return YouTubePlaylistVideo(
                id: item.id,
                channelID: item.snippet.channelID,
                channelTitle: item.snippet.channelTitle,
                title: item.snippet.title,
                publishedAt: item.snippet.publishedAt,
                videoURL: URL(string: "https://www.youtube.com/watch?v=\(item.id)"),
                thumbnailURL: YouTubeThumbnailCandidates.preferredURL(for: item.id),
                durationSeconds: parseDuration(duration),
                viewCount: item.statistics?.viewCount.flatMap(Int.init)
            )
        }
    }

    static func mergeVideos(_ videos: [YouTubePlaylistVideo], preferredOrder: [String]) -> [YouTubePlaylistVideo] {
        let order = Dictionary(uniqueKeysWithValues: preferredOrder.enumerated().map { ($1, $0) })
        return videos.sorted { lhs, rhs in
            switch (lhs.publishedAt, rhs.publishedAt) {
            case let (left?, right?) where left != right:
                return left > right
            default:
                return (order[lhs.id] ?? .max) < (order[rhs.id] ?? .max)
            }
        }
    }
}
