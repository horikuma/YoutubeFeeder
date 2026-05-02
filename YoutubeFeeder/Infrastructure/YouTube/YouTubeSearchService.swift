import Foundation

struct YouTubeSearchService {
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

    func searchVideos(keyword: String, limit: Int = 100) async throws -> YouTubeSearchResponse {
        let logger = AppConsoleLogger.youtubeSearch
        let startedAt = Date()
        let keywordPreview = AppConsoleLogger.sanitizedKeyword(keyword)
        var stage = "prepare"
        logRequestStart(keywordPreview: keywordPreview, limit: limit, logger: logger)

        do {
            if AppLaunchMode.current.usesMockData {
                return try await performMockSearch(
                    keyword: keyword,
                    limit: limit,
                    keywordPreview: keywordPreview,
                    startedAt: startedAt,
                    logger: logger,
                    stage: &stage
                )
            }

            let apiKey = try resolveAPIKey(keywordPreview: keywordPreview, logger: logger)
            let selection = try await fetchSelectedVideoIDs(
                keyword: keyword,
                limit: limit,
                apiKey: apiKey,
                stage: &stage
            )
            stage = "video_details"
            let detailedVideos = try await fetchVideoDetails(videoIDs: selection.videoIDs, apiKey: apiKey)
            stage = "merge_details"
            let videos = Self.mergeDetailedVideos(detailedVideos, preferredOrder: selection.videoIDs)
            let response = YouTubeSearchResponse(videos: videos, totalCount: videos.count, fetchedAt: .now)
            logger.info("request_complete", metadata: selection.completionMetadata(
                keywordPreview: keywordPreview,
                videoCount: videos.count,
                startedAt: startedAt
            ))
            return response
        } catch {
            handleSearchFailure(error, keywordPreview: keywordPreview, stage: stage, startedAt: startedAt, logger: logger)
            throw error
        }
    }

    func searchChannelVideos(channelID: String, limit: Int = 50) async throws -> YouTubeSearchResponse {
        let page = try await fetchChannelVideosPage(channelID: channelID, pageToken: nil, limit: limit)
        return YouTubeSearchResponse(videos: page.videos, totalCount: page.totalCount, fetchedAt: page.fetchedAt)
    }

    func fetchChannelVideosPage(
        channelID: String,
        pageToken: String?,
        limit: Int = 50
    ) async throws -> YouTubeChannelVideosPage {
        let logger = AppConsoleLogger.youtubeSearch
        let startedAt = Date()
        var stage = "prepare"

        do {
            if AppLaunchMode.current.usesMockData {
                stage = "mock_response"
                let response = mockChannelVideosPageResponse(channelID: channelID, limit: limit)
                logger.info(
                    "channel_request_complete",
                    metadata: [
                        "channelID": channelID,
                        "videos": String(response.videos.count),
                        "source": "mock",
                        "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                    ]
                )
                return response
            }

            let apiKey = try resolveAPIKey(keywordPreview: channelID, logger: logger)
            stage = "channel_playlist"
            let page = try await fetchChannelVideosPage(
                channelID: channelID,
                pageToken: pageToken,
                limit: min(limit, 50),
                apiKey: apiKey
            )
            logger.info(
                "channel_request_complete",
                metadata: [
                    "channelID": channelID,
                    "videos": String(page.videos.count),
                    "selected_ids": String(page.videos.count),
                    "next_page_token": page.nextPageToken ?? "",
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                ]
            )
            return page
        } catch {
            handleSearchFailure(error, keywordPreview: channelID, stage: stage, startedAt: startedAt, logger: logger)
            throw error
        }
    }

    private func logRequestStart(keywordPreview: String, limit: Int, logger: AppConsoleLogger) {
        logger.info(
            "request_start",
            metadata: [
                "keyword": keywordPreview,
                "limit": String(limit),
                "mode": AppLaunchMode.current.usesMockData ? "mock" : "live"
            ]
        )
    }

    private func performMockSearch(
        keyword: String,
        limit: Int,
        keywordPreview: String,
        startedAt: Date,
        logger: AppConsoleLogger,
        stage: inout String
    ) async throws -> YouTubeSearchResponse {
        stage = "mock_delay"
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        stage = "mock_response"
        let response = mockSearchResponse(keyword: keyword, limit: limit)
        logger.info(
            "request_complete",
            metadata: [
                "keyword": keywordPreview,
                "videos": String(response.videos.count),
                "source": "mock",
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
            ]
        )
        return response
    }

    private func resolveAPIKey(keywordPreview: String, logger: AppConsoleLogger) throws -> String {
        guard let apiKey = resolvedAPIKey else {
            logger.error(
                "config_missing",
                message: YouTubeSearchError.apiKeyMissing.localizedDescription,
                metadata: ["keyword": keywordPreview]
            )
            throw YouTubeSearchError.apiKeyMissing
        }
        return apiKey
    }

    private func fetchSelectedVideoIDs(
        keyword: String,
        limit: Int,
        apiKey: String,
        stage: inout String
    ) async throws -> CandidateSelection {
        stage = "candidate_medium"
        let mediumCandidates = try await searchCandidates(
            keyword: keyword,
            duration: "medium",
            apiKey: apiKey,
            maxResults: 50
        )
        stage = "candidate_long"
        let longCandidates = try await searchCandidates(
            keyword: keyword,
            duration: "long",
            apiKey: apiKey,
            maxResults: 50
        )
        stage = "merge_candidates"
        let mergedCandidates = Self.mergeCandidates(mediumCandidates + longCandidates)
        return CandidateSelection(
            mediumCandidateCount: mediumCandidates.count,
            longCandidateCount: longCandidates.count,
            videoIDs: Array(mergedCandidates.map(\.id).prefix(limit))
        )
    }

    private func handleSearchFailure(
        _ error: Error,
        keywordPreview: String,
        stage: String,
        startedAt: Date,
        logger: AppConsoleLogger
    ) {
        let metadata = [
            "keyword": keywordPreview,
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

    private func searchCandidates(
        keyword: String,
        duration: String,
        apiKey: String,
        maxResults: Int
    ) async throws -> [SearchCandidate] {
        let logger = AppConsoleLogger.youtubeSearch
        let startedAt = Date()
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")
        components?.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "q", value: keyword),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "order", value: "date"),
            URLQueryItem(name: "videoDuration", value: duration),
            URLQueryItem(name: "videoEmbeddable", value: "true"),
            URLQueryItem(name: "maxResults", value: String(maxResults)),
        ]

        guard let url = components?.url else {
            throw YouTubeSearchError.invalidResponse
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")

        logger.info(
            "candidate_request_start",
            metadata: ["duration": duration, "max_results": String(maxResults), "keyword": AppConsoleLogger.sanitizedKeyword(keyword)]
        )

        let data = try await loadData(
            for: request,
            endpoint: "search",
            metadata: ["duration": duration, "max_results": String(maxResults)]
        )
        let response = try decodeResponse(SearchListResponse.self, from: data, endpoint: "search", metadata: ["duration": duration])
        let candidates: [SearchCandidate] = response.items.compactMap { item in
            guard let videoID = item.id.videoID else { return nil }
            return SearchCandidate(id: videoID, publishedAt: item.snippet.publishedAt)
        }
        logger.info(
            "candidate_request_complete",
            metadata: [
                "duration": duration,
                "items": String(candidates.count),
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
            ]
        )
        return candidates
    }

    private func fetchChannelVideosPage(
        channelID: String,
        pageToken: String?,
        limit: Int,
        apiKey: String,
    ) async throws -> YouTubeChannelVideosPage {
        let uploadsPlaylistID = try await fetchChannelUploadsPlaylistID(channelID: channelID, apiKey: apiKey)
        let playlistItems = try await fetchPlaylistItems(
            playlistID: uploadsPlaylistID,
            pageToken: pageToken,
            apiKey: apiKey,
            maxResults: limit
        )
        let videoIDs = playlistItems.items.compactMap(\.contentDetails?.videoID)

        let detailedVideos = try await fetchVideoDetails(videoIDs: videoIDs, apiKey: apiKey)
        let videos = Self.mergeDetailedVideos(detailedVideos, preferredOrder: videoIDs)
            .filter {
                !ShortVideoMaskPolicy.shouldMask(
                    durationSeconds: $0.durationSeconds,
                    videoURL: $0.videoURL,
                    title: $0.title
                )
            }
        return YouTubeChannelVideosPage(
            videos: videos,
            totalCount: playlistItems.pageInfo?.totalResults ?? videos.count,
            fetchedAt: .now,
            nextPageToken: playlistItems.nextPageToken
        )
    }

    private func fetchChannelUploadsPlaylistID(
        channelID: String,
        apiKey: String
    ) async throws -> String {
        let logger = AppConsoleLogger.youtubeSearch
        let startedAt = Date()
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/channels")
        components?.queryItems = [
            URLQueryItem(name: "part", value: "contentDetails"),
            URLQueryItem(name: "id", value: channelID),
        ]

        guard let url = components?.url else {
            throw YouTubeSearchError.invalidResponse
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")

        logger.info("channel_uploads_request_start", metadata: ["channelID": channelID])

        let data = try await loadData(
            for: request,
            endpoint: "channels",
            metadata: ["channelID": channelID]
        )
        let response = try decodeResponse(
            ChannelsListResponse.self,
            from: data,
            endpoint: "channels",
            metadata: ["channelID": channelID]
        )
        guard let uploadsPlaylistID = response.items.first?.contentDetails.relatedPlaylists.uploads,
              !uploadsPlaylistID.isEmpty
        else {
            logger.error(
                "channel_uploads_missing",
                message: "チャンネルの uploads プレイリストを取得できませんでした。",
                metadata: [
                    "channelID": channelID,
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                ]
            )
            throw YouTubeSearchError.invalidResponse
        }

        logger.info(
            "channel_uploads_request_complete",
            metadata: [
                "channelID": channelID,
                "uploads_playlist_id": uploadsPlaylistID,
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
            ]
        )
        return uploadsPlaylistID
    }

    private func fetchPlaylistItems(
        playlistID: String,
        pageToken: String?,
        apiKey: String,
        maxResults: Int
    ) async throws -> PlaylistItemsListResponse {
        let logger = AppConsoleLogger.youtubeSearch
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

        logger.info(
            "playlist_items_request_start",
            metadata: [
                "playlist_id": playlistID,
                "page_token": pageToken ?? "",
                "max_results": String(max(1, min(maxResults, 50))),
            ]
        )

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
        logger.info(
            "playlist_items_request_complete",
            metadata: [
                "playlist_id": playlistID,
                "page_token": pageToken ?? "",
                "items": String(response.items.count),
                "next_page_token": response.nextPageToken ?? "",
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
            ]
        )
        return response
    }

    func fetchVideoDetails(videoIDs: [String], apiKey: String) async throws -> [YouTubeSearchVideo] {
        guard !videoIDs.isEmpty else { return [] }

        let logger = AppConsoleLogger.youtubeSearch
        let startedAt = Date()
        var mergedVideos: [YouTubeSearchVideo] = []
        let batches = chunkVideoIDs(videoIDs, size: 50)
        logger.info(
            "video_details_start",
            metadata: ["video_ids": String(videoIDs.count), "batches": String(batches.count)]
        )
        for (index, batch) in batches.enumerated() {
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
                metadata: ["batch": "\(index + 1)/\(batches.count)", "ids": String(batch.count)]
            )
            let response = try decodeResponse(
                VideoListResponse.self,
                from: data,
                endpoint: "videos",
                metadata: ["batch": "\(index + 1)/\(batches.count)"]
            )
            let videos = Self.filterPlayableVideos(response.items)
            mergedVideos.append(contentsOf: videos)
            logger.info(
                "video_details_batch_complete",
                metadata: ["batch": "\(index + 1)/\(batches.count)", "videos": String(videos.count)]
            )
        }

        logger.info(
            "video_details_complete",
            metadata: ["videos": String(mergedVideos.count), "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)]
        )
        return mergedVideos
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

}

private struct CandidateSelection {
    let mediumCandidateCount: Int
    let longCandidateCount: Int
    let videoIDs: [String]

    func completionMetadata(keywordPreview: String, videoCount: Int, startedAt: Date) -> [String: String] {
        [
            "keyword": keywordPreview,
            "medium_candidates": String(mediumCandidateCount),
            "long_candidates": String(longCandidateCount),
            "selected_ids": String(videoIDs.count),
            "videos": String(videoCount),
            "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
        ]
    }
}
