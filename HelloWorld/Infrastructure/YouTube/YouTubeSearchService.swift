import Foundation

struct YouTubeSearchVideo: Hashable {
    let id: String
    let channelID: String
    let channelTitle: String
    let title: String
    let publishedAt: Date?
    let videoURL: URL?
    let thumbnailURL: URL?
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

    func searchVideos(keyword: String, limit: Int = 20) async throws -> YouTubeSearchResponse {
        guard let apiKey = resolvedAPIKey else {
            throw YouTubeSearchError.apiKeyMissing
        }

        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")
        components?.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "q", value: keyword),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "order", value: "date"),
            URLQueryItem(name: "maxResults", value: String(limit)),
        ]

        guard let url = components?.url else {
            throw YouTubeSearchError.invalidResponse
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder.youtubeAPI.decode(SearchListResponse.self, from: data)

        let videos = response.items.compactMap { item -> YouTubeSearchVideo? in
            guard let videoID = item.id.videoID else { return nil }
            let thumbnailURL = item.snippet.thumbnails.high?.url
                ?? item.snippet.thumbnails.medium?.url
                ?? item.snippet.thumbnails.defaultThumbnail?.url
            return YouTubeSearchVideo(
                id: videoID,
                channelID: item.snippet.channelID,
                channelTitle: item.snippet.channelTitle,
                title: item.snippet.title,
                publishedAt: item.snippet.publishedAt,
                videoURL: URL(string: "https://www.youtube.com/watch?v=\(videoID)"),
                thumbnailURL: thumbnailURL
            )
        }

        return YouTubeSearchResponse(videos: videos, totalCount: response.pageInfo.totalResults, fetchedAt: .now)
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
        let thumbnails: Thumbnails

        private enum CodingKeys: String, CodingKey {
            case publishedAt
            case channelID = "channelId"
            case channelTitle
            case title
            case thumbnails
        }
    }

    struct Thumbnails: Decodable {
        let defaultThumbnail: Thumbnail?
        let medium: Thumbnail?
        let high: Thumbnail?

        private enum CodingKeys: String, CodingKey {
            case defaultThumbnail = "default"
            case medium
            case high
        }
    }

    struct Thumbnail: Decodable {
        let url: URL?
    }

    struct PageInfo: Decodable {
        let totalResults: Int
    }
}

private extension JSONDecoder {
    static let youtubeAPI: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
