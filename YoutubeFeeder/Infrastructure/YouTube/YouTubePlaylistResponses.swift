import Foundation

struct PlaylistsListResponse: Decodable {
    let items: [Item]
    let nextPageToken: String?
    let pageInfo: PageInfo?

    struct Item: Decodable {
        let id: String
        let snippet: Snippet
        let contentDetails: ContentDetails?
    }

    struct Snippet: Decodable {
        let publishedAt: Date?
        let channelID: String
        let channelTitle: String
        let title: String
        let description: String?
        let thumbnails: VideoThumbnails

        private enum CodingKeys: String, CodingKey {
            case publishedAt
            case channelID = "channelId"
            case channelTitle
            case title
            case description
            case thumbnails
        }
    }

    struct ContentDetails: Decodable {
        let itemCount: Int?
    }

    struct PageInfo: Decodable {
        let totalResults: Int
    }
}

struct PlaylistItemsListResponse: Decodable {
    let items: [Item]
    let nextPageToken: String?
    let pageInfo: PageInfo?

    struct Item: Decodable {
        let contentDetails: ContentDetails?
    }

    struct ContentDetails: Decodable {
        let videoID: String?

        private enum CodingKeys: String, CodingKey {
            case videoID = "videoId"
        }
    }

    struct PageInfo: Decodable {
        let totalResults: Int
    }
}
