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

struct SearchCandidate: Hashable {
    let id: String
    let publishedAt: Date?
}
