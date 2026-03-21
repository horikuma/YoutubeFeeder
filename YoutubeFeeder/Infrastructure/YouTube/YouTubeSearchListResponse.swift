import Foundation

struct SearchListResponse: Decodable {
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
