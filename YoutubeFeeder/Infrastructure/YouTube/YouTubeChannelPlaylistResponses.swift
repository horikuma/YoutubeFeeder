import Foundation

struct ChannelsListResponse: Decodable {
    let items: [Item]

    struct Item: Decodable {
        let contentDetails: ContentDetails
    }

    struct ContentDetails: Decodable {
        let relatedPlaylists: RelatedPlaylists
    }

    struct RelatedPlaylists: Decodable {
        let uploads: String?
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
