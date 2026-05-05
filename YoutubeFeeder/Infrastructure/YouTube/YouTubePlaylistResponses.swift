import Foundation

struct PlaylistsListResponse: Decodable {
    let items: [Item]
    let nextPageToken: String?
    let pageInfo: PlaylistsListPageInfo?

    struct Item: Decodable {
        let id: String
        let snippet: PlaylistsListSnippet
        let contentDetails: PlaylistsListContentDetails?
    }
}

struct PlaylistsListSnippet: Decodable {
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

struct PlaylistsListContentDetails: Decodable {
    let itemCount: Int?
}

struct PlaylistsListPageInfo: Decodable {
    let totalResults: Int
}

struct PlaylistItemsListResponse: Decodable {
    let items: [Item]
    let nextPageToken: String?
    let pageInfo: PlaylistItemsListPageInfo?

    struct Item: Decodable {
        let contentDetails: PlaylistItemsListContentDetails?
    }
}

struct PlaylistItemsListContentDetails: Decodable {
    let videoID: String?

    private enum CodingKeys: String, CodingKey {
        case videoID = "videoId"
    }
}

struct PlaylistItemsListPageInfo: Decodable {
    let totalResults: Int
}
