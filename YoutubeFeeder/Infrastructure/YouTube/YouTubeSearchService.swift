import Foundation

struct YouTubeSearchService {
    nonisolated static let videoDetailsPartParameter = "snippet,contentDetails,statistics,liveStreamingDetails"

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
            logger.notice("request_complete", metadata: selection.completionMetadata(
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
        let logger = AppConsoleLogger.youtubeSearch
        let startedAt = Date()
        var stage = "prepare"

        do {
            if AppLaunchMode.current.usesMockData {
                stage = "mock_response"
                let response = mockChannelSearchResponse(channelID: channelID, limit: limit)
                logger.notice(
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
            stage = "channel_candidates"
            let videoIDs = try await searchChannelVideoIDs(
                channelID: channelID,
                apiKey: apiKey,
                maxResults: min(limit, 50)
            )
            stage = "video_details"
            let detailedVideos = try await fetchVideoDetails(videoIDs: videoIDs, apiKey: apiKey)
            stage = "merge_details"
            let videos = Self.mergeDetailedVideos(detailedVideos, preferredOrder: videoIDs)
                .filter {
                    !ShortVideoMaskPolicy.shouldMask(
                        durationSeconds: $0.durationSeconds,
                        videoURL: $0.videoURL,
                        title: $0.title
                    )
                }
            let response = YouTubeSearchResponse(videos: videos, totalCount: videos.count, fetchedAt: .now)
            logger.notice(
                "channel_request_complete",
                metadata: [
                    "channelID": channelID,
                    "videos": String(videos.count),
                    "selected_ids": String(videoIDs.count),
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                ]
            )
            return response
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
        logger.notice(
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
            logger.notice("request_cancelled", metadata: metadata)
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

        logger.debug(
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
        logger.debug(
            "candidate_request_complete",
            metadata: [
                "duration": duration,
                "items": String(candidates.count),
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
            ]
        )
        return candidates
    }

    private func searchChannelVideoIDs(
        channelID: String,
        apiKey: String,
        maxResults: Int
    ) async throws -> [String] {
        let logger = AppConsoleLogger.youtubeSearch
        let startedAt = Date()
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")
        components?.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "channelId", value: channelID),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "order", value: "date"),
            URLQueryItem(name: "videoEmbeddable", value: "true"),
            URLQueryItem(name: "maxResults", value: String(maxResults)),
        ]

        guard let url = components?.url else {
            throw YouTubeSearchError.invalidResponse
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")

        logger.debug(
            "channel_candidate_request_start",
            metadata: ["channelID": channelID, "max_results": String(maxResults)]
        )

        let data = try await loadData(
            for: request,
            endpoint: "search",
            metadata: ["channelID": channelID, "max_results": String(maxResults)]
        )
        let response = try decodeResponse(
            SearchListResponse.self,
            from: data,
            endpoint: "search",
            metadata: ["channelID": channelID]
        )
        let ids = response.items.compactMap(\.id.videoID)
        logger.debug(
            "channel_candidate_request_complete",
            metadata: [
                "channelID": channelID,
                "items": String(ids.count),
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
            ]
        )
        return ids
    }

    private func fetchVideoDetails(videoIDs: [String], apiKey: String) async throws -> [YouTubeSearchVideo] {
        guard !videoIDs.isEmpty else { return [] }

        let logger = AppConsoleLogger.youtubeSearch
        let startedAt = Date()
        var mergedVideos: [YouTubeSearchVideo] = []
        let batches = chunkVideoIDs(videoIDs, size: 50)
        logger.debug(
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
            logger.debug(
                "video_details_batch_complete",
                metadata: ["batch": "\(index + 1)/\(batches.count)", "videos": String(videos.count)]
            )
        }

        logger.debug(
            "video_details_complete",
            metadata: ["videos": String(mergedVideos.count), "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)]
        )
        return mergedVideos
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
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            let transportMetadata = transportFailureMetadata(metadata, endpoint: endpoint, startedAt: startedAt, error: error)
            logTransportFailure(error, metadata: transportMetadata, logger: logger)
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

        logger.debug("http_success", metadata: responseMetadata)
        return data
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
            logger.notice("http_cancelled", metadata: metadata)
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
