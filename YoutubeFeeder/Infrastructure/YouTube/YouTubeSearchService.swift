import Foundation

struct YouTubeSearchVideo: Hashable {
    let id: String
    let channelID: String
    let channelTitle: String
    let title: String
    let publishedAt: Date?
    let videoURL: URL?
    let thumbnailURL: URL?
    let durationSeconds: Int?
    let viewCount: Int?
}

struct YouTubeSearchResponse: Hashable {
    let videos: [YouTubeSearchVideo]
    let totalCount: Int
    let fetchedAt: Date
}

enum YouTubeSearchError: LocalizedError {
    case apiKeyMissing
    case invalidResponse
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "YouTube 検索 API キーが未設定です。"
        case .invalidResponse:
            return "YouTube 検索結果を読み取れませんでした。"
        case let .httpError(statusCode):
            return "YouTube 検索 API が失敗しました。(status: \(statusCode))"
        }
    }
}

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
        logger.info(
            "request_start",
            metadata: ["keyword": keywordPreview, "limit": String(limit), "mode": AppLaunchMode.current.usesMockData ? "mock" : "live"]
        )

        do {
            if AppLaunchMode.current.usesMockData {
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

            guard let apiKey = resolvedAPIKey else {
                logger.error(
                    "config_missing",
                    message: YouTubeSearchError.apiKeyMissing.localizedDescription,
                    metadata: ["keyword": keywordPreview]
                )
                throw YouTubeSearchError.apiKeyMissing
            }
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
            let videoIDs = Array(mergedCandidates.map(\.id).prefix(limit))
            stage = "video_details"
            let detailedVideos = try await fetchVideoDetails(videoIDs: videoIDs, apiKey: apiKey)
            stage = "merge_details"
            let videos = Self.mergeDetailedVideos(detailedVideos, preferredOrder: videoIDs)
            let response = YouTubeSearchResponse(videos: videos, totalCount: videos.count, fetchedAt: .now)
            logger.notice(
                "request_complete",
                metadata: [
                    "keyword": keywordPreview,
                    "medium_candidates": String(mediumCandidates.count),
                    "long_candidates": String(longCandidates.count),
                    "selected_ids": String(videoIDs.count),
                    "videos": String(videos.count),
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                ]
            )
            return response
        } catch {
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
            throw error
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

    private func fetchVideoDetails(videoIDs: [String], apiKey: String) async throws -> [YouTubeSearchVideo] {
        guard !videoIDs.isEmpty else { return [] }

        let logger = AppConsoleLogger.youtubeSearch
        let startedAt = Date()
        var mergedVideos: [YouTubeSearchVideo] = []
        let batches = videoIDs.chunked(into: 50)
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
            let transportMetadata = metadata.merging(
                [
                    "endpoint": endpoint,
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                    "reason": RemoteSearchErrorPolicy.diagnosticReason(for: error),
                ],
                uniquingKeysWith: { _, new in new }
            )
            if RemoteSearchErrorPolicy.isCancellation(error) {
                logger.notice("http_cancelled", metadata: transportMetadata)
            } else {
                logger.error(
                    "http_transport_failure",
                    message: AppConsoleLogger.errorSummary(error),
                    metadata: transportMetadata
                )
            }
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            let invalidResponseMetadata = metadata.merging(
                ["endpoint": endpoint, "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)],
                uniquingKeysWith: { _, new in new }
            )
            logger.error(
                "response_invalid",
                message: "HTTP response を取得できませんでした。",
                metadata: invalidResponseMetadata
            )
            throw YouTubeSearchError.invalidResponse
        }

        let responseMetadata = metadata.merging(
            [
                "endpoint": endpoint,
                "status": String(httpResponse.statusCode),
                "bytes": String(data.count),
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
            ]
        ) { _, new in new }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let failureMetadata = responseMetadata.merging(
                ["body_preview": AppConsoleLogger.responsePreview(data)],
                uniquingKeysWith: { _, new in new }
            )
            logger.error(
                "http_failure",
                message: "YouTube API が失敗しました。",
                metadata: failureMetadata
            )
            throw YouTubeSearchError.httpError(statusCode: httpResponse.statusCode)
        }

        logger.debug("http_success", metadata: responseMetadata)
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

    static func mergeCandidates(_ candidates: [SearchCandidate]) -> [SearchCandidate] {
        let deduplicated = candidates.reduce(into: [String: SearchCandidate]()) { partial, candidate in
            guard let existing = partial[candidate.id] else {
                partial[candidate.id] = candidate
                return
            }

            switch (candidate.publishedAt, existing.publishedAt) {
            case let (left?, right?) where left > right:
                partial[candidate.id] = candidate
            case (_?, nil):
                partial[candidate.id] = candidate
            default:
                break
            }
        }

        return deduplicated.values.sorted {
            switch ($0.publishedAt, $1.publishedAt) {
            case let (left?, right?) where left != right:
                return left > right
            case (_?, _?):
                return $0.id < $1.id
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return $0.id < $1.id
            }
        }
    }

    static func filterPlayableVideos(_ items: [VideoListResponse.Item]) -> [YouTubeSearchVideo] {
        items.compactMap { item in
            guard item.snippet.liveBroadcastContent == "none" else { return nil }
            guard item.liveStreamingDetails == nil else { return nil }
            let thumbnailURL = item.snippet.thumbnails.high?.url
                ?? item.snippet.thumbnails.medium?.url
                ?? item.snippet.thumbnails.defaultThumbnail?.url
            return YouTubeSearchVideo(
                id: item.id,
                channelID: item.snippet.channelID,
                channelTitle: item.snippet.channelTitle,
                title: item.snippet.title,
                publishedAt: item.snippet.publishedAt,
                videoURL: URL(string: "https://www.youtube.com/watch?v=\(item.id)"),
                thumbnailURL: thumbnailURL,
                durationSeconds: parseDuration(item.contentDetails.duration),
                viewCount: item.statistics?.viewCount.flatMap(Int.init)
            )
        }
    }

    static func mergeDetailedVideos(_ videos: [YouTubeSearchVideo], preferredOrder: [String]) -> [YouTubeSearchVideo] {
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

    private func mockSearchResponse(keyword: String, limit: Int) -> YouTubeSearchResponse {
        let videos = [
            YouTubeSearchVideo(
                id: "remote-refresh-001",
                channelID: "UC_REMOTE_REFRESH",
                channelTitle: "Refresh Channel",
                title: "\(keyword) 最新テスト動画",
                publishedAt: .now.addingTimeInterval(60),
                videoURL: URL(string: "https://www.youtube.com/watch?v=remote-refresh-001"),
                thumbnailURL: URL(string: "https://example.com/remote-refresh-001.jpg"),
                durationSeconds: 1240,
                viewCount: 4242
            ),
            YouTubeSearchVideo(
                id: "remote-refresh-002",
                channelID: "UC_REMOTE_REFRESH",
                channelTitle: "Refresh Channel",
                title: "\(keyword) 追加テスト動画",
                publishedAt: .now,
                videoURL: URL(string: "https://www.youtube.com/watch?v=remote-refresh-002"),
                thumbnailURL: URL(string: "https://example.com/remote-refresh-002.jpg"),
                durationSeconds: 980,
                viewCount: 2024
            )
        ]
        return YouTubeSearchResponse(
            videos: Array(videos.prefix(limit)),
            totalCount: min(videos.count, limit),
            fetchedAt: .now
        )
    }
}

struct SearchCandidate: Hashable {
    let id: String
    let publishedAt: Date?
}

private struct SearchListResponse: Decodable {
    let items: [Item]
    let pageInfo: PageInfo

    struct Item: Decodable {
        let id: Identifier
        let snippet: Snippet
    }

    struct Identifier: Decodable {
        let videoID: String?

        private enum CodingKeys: String, CodingKey {
            case videoID = "videoId"
        }
    }

    struct Snippet: Decodable {
        let publishedAt: Date?
        let channelID: String
        let channelTitle: String
        let title: String
        let liveBroadcastContent: String?
        let thumbnails: VideoThumbnails

        private enum CodingKeys: String, CodingKey {
            case publishedAt
            case channelID = "channelId"
            case channelTitle
            case title
            case liveBroadcastContent
            case thumbnails
        }
    }

    struct PageInfo: Decodable {
        let totalResults: Int
    }
}

struct VideoListResponse: Decodable {
    let items: [Item]

    struct Item: Decodable {
        let id: String
        let snippet: Snippet
        let contentDetails: ContentDetails
        let statistics: Statistics?
        let liveStreamingDetails: LiveStreamingDetails?
    }

    struct Snippet: Decodable {
        let publishedAt: Date?
        let channelID: String
        let channelTitle: String
        let title: String
        let liveBroadcastContent: String?
        let thumbnails: VideoThumbnails

        private enum CodingKeys: String, CodingKey {
            case publishedAt
            case channelID = "channelId"
            case channelTitle
            case title
            case liveBroadcastContent
            case thumbnails
        }
    }

    struct ContentDetails: Decodable {
        let duration: String
    }

    struct Statistics: Decodable {
        let viewCount: String?
    }

    struct LiveStreamingDetails: Decodable {}
}

struct VideoThumbnails: Decodable {
    let defaultThumbnail: VideoThumbnail?
    let medium: VideoThumbnail?
    let high: VideoThumbnail?

    private enum CodingKeys: String, CodingKey {
        case defaultThumbnail = "default"
        case medium
        case high
    }
}

struct VideoThumbnail: Decodable {
    let url: URL?
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var result: [[Element]] = []
        var index = startIndex
        while index < endIndex {
            let nextIndex = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            result.append(Array(self[index ..< nextIndex]))
            index = nextIndex
        }
        return result
    }
}

private extension JSONDecoder {
    static let youtubeAPI: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

private func parseDuration(_ rawValue: String) -> Int? {
    guard rawValue.hasPrefix("PT") else { return nil }

    var total = 0
    var buffer = ""
    for character in rawValue.dropFirst(2) {
        if character.isNumber {
            buffer.append(character)
            continue
        }

        guard let value = Int(buffer) else { continue }
        switch character {
        case "H":
            total += value * 3_600
        case "M":
            total += value * 60
        case "S":
            total += value
        default:
            break
        }
        buffer.removeAll(keepingCapacity: true)
    }

    return total > 0 ? total : nil
}
