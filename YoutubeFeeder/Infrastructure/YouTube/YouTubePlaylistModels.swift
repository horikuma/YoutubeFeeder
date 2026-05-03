import Foundation

struct YouTubePlaylistListItem: Hashable {
    let id: String
    let channelID: String
    let channelTitle: String
    let title: String
    let description: String?
    let publishedAt: Date?
    let itemCount: Int?
    let thumbnailURL: URL?
}

struct YouTubePlaylistVideo: Hashable {
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

struct YouTubePlaylistVideosPage: Hashable {
    let playlistID: String
    let videos: [YouTubePlaylistVideo]
    let totalCount: Int
    let fetchedAt: Date
    let nextPageToken: String?
}
