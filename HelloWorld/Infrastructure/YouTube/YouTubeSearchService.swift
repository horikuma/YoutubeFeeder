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

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "YouTube 検索 API キーが未設定です。"
        case .invalidResponse:
            return "YouTube 検索結果を読み取れませんでした。"
        }
    }
}

struct YouTubeSearchService {
    var isConfigured: Bool {
        resolvedAPIKey != nil
    }

    func searchVideos(keyword: String, limit: Int = 100) async throws -> YouTubeSearchResponse {
        guard let apiKey = resolvedAPIKey else {
            throw YouTubeSearchError.apiKeyMissing
        }
        let mediumCandidates = try await searchCandidates(
            keyword: keyword,
            duration: "medium",
            apiKey: apiKey,
            maxResults: 50
        )
        let longCandidates = try await searchCandidates(
            keyword: keyword,
            duration: "long",
            apiKey: apiKey,
            maxResults: 50
        )

        let mergedCandidates = Self.mergeCandidates(mediumCandidates + longCandidates)
        let videoIDs = Array(mergedCandidates.map(\.id).prefix(limit))
        let detailedVideos = try await fetchVideoDetails(videoIDs: videoIDs, apiKey: apiKey)
        let videos = Self.mergeDetailedVideos(detailedVideos, preferredOrder: videoIDs)
        return YouTubeSearchResponse(videos: videos, totalCount: videos.count, fetchedAt: .now)
    }

    private var resolvedAPIKey: String? {
        let environmentKey = ProcessInfo.processInfo.environment["HELLOWORLD_YOUTUBE_API_KEY"]?
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

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder.youtubeAPI.decode(SearchListResponse.self, from: data)
        return response.items.compactMap { item in
            guard let videoID = item.id.videoID else { return nil }
            return SearchCandidate(id: videoID, publishedAt: item.snippet.publishedAt)
        }
    }

    private func fetchVideoDetails(videoIDs: [String], apiKey: String) async throws -> [YouTubeSearchVideo] {
        guard !videoIDs.isEmpty else { return [] }

        var mergedVideos: [YouTubeSearchVideo] = []
        for batch in videoIDs.chunked(into: 50) {
            var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/videos")
            components?.queryItems = [
                URLQueryItem(name: "part", value: "snippet,contentDetails,liveStreamingDetails"),
                URLQueryItem(name: "id", value: batch.joined(separator: ",")),
                URLQueryItem(name: "maxResults", value: String(batch.count)),
            ]

            guard let url = components?.url else {
                throw YouTubeSearchError.invalidResponse
            }

            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
            request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")

            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder.youtubeAPI.decode(VideoListResponse.self, from: data)
            mergedVideos.append(contentsOf: Self.filterPlayableVideos(response.items))
        }

        return mergedVideos
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
