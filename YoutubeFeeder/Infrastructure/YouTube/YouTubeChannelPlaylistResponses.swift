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
