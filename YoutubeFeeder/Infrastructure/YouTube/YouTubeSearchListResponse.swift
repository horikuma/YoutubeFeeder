import Foundation

struct SearchListResponse: Decodable {
    let items: [Item]
    let pageInfo: SearchListPageInfo

    struct Item: Decodable {
        let id: SearchListIdentifier
        let snippet: SearchListSnippet
    }
}

struct SearchListIdentifier: Decodable {
    let videoID: String?

    private enum CodingKeys: String, CodingKey {
        case videoID = "videoId"
    }
}

struct SearchListSnippet: Decodable {
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

struct SearchListPageInfo: Decodable {
    let totalResults: Int
}
