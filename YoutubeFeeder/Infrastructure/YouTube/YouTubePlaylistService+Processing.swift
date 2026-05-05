import Foundation

enum YouTubePlaylistServiceProcessing {
    static func mockPlaylistsResponse(channelID: String, limit: Int) -> [YouTubePlaylistListItem] {
        let playlists = [
            YouTubePlaylistListItem(
                id: "\(channelID)-playlist-001",
                channelID: channelID,
                channelTitle: "Channel \(channelID)",
                title: "Playlist 1",
                description: "Mock playlist 1",
                publishedAt: .now.addingTimeInterval(-3_600),
                itemCount: 12,
                thumbnailURL: URL(string: "https://example.com/\(channelID)-playlist-001.jpg")
            ),
            YouTubePlaylistListItem(
                id: "\(channelID)-playlist-002",
                channelID: channelID,
                channelTitle: "Channel \(channelID)",
                title: "Playlist 2",
                description: "Mock playlist 2",
                publishedAt: .now.addingTimeInterval(-7_200),
                itemCount: 24,
                thumbnailURL: URL(string: "https://example.com/\(channelID)-playlist-002.jpg")
            ),
            YouTubePlaylistListItem(
                id: "\(channelID)-playlist-003",
                channelID: channelID,
                channelTitle: "Channel \(channelID)",
                title: "Playlist 3",
                description: "Mock playlist 3",
                publishedAt: .now.addingTimeInterval(-10_800),
                itemCount: 6,
                thumbnailURL: URL(string: "https://example.com/\(channelID)-playlist-003.jpg")
            )
        ]
        return Array(playlists.prefix(max(0, limit)))
    }

    static func mockPlaylistVideosPage(playlistID: String, limit: Int) -> YouTubePlaylistVideosPage {
        let videos = (1 ... 12).map { index in
            YouTubePlaylistVideo(
                id: "\(playlistID)-video-\(index)",
                channelID: "UC_MOCK_PLAYLIST",
                channelTitle: "Mock Playlist Channel",
                title: "Playlist video \(index)",
                publishedAt: .now.addingTimeInterval(TimeInterval(-index * 900)),
                videoURL: URL(string: "https://www.youtube.com/watch?v=\(playlistID)-video-\(index)"),
                thumbnailURL: URL(string: "https://example.com/\(playlistID)-video-\(index).jpg"),
                durationSeconds: 900 + index,
                viewCount: 1_000 + index
            )
        }
        return YouTubePlaylistVideosPage(
            playlistID: playlistID,
            videos: Array(videos.prefix(max(0, limit))),
            totalCount: videos.count,
            fetchedAt: .now,
            nextPageToken: nil
        )
    }

    static func preferredThumbnailURL(from thumbnails: VideoThumbnails) -> URL? {
        thumbnails.high?.url ?? thumbnails.medium?.url ?? thumbnails.defaultThumbnail?.url
    }

    static func filterPlayableVideos(_ items: [VideoListResponse.Item]) -> [YouTubePlaylistVideo] {
        items.compactMap { item in
            guard item.snippet.liveBroadcastContent == "none" else { return nil }
            guard item.liveStreamingDetails == nil else { return nil }
            guard let duration = item.contentDetails?.duration else { return nil }
            return YouTubePlaylistVideo(
                id: item.id,
                channelID: item.snippet.channelID,
                channelTitle: item.snippet.channelTitle,
                title: item.snippet.title,
                publishedAt: item.snippet.publishedAt,
                videoURL: URL(string: "https://www.youtube.com/watch?v=\(item.id)"),
                thumbnailURL: YouTubeThumbnailCandidates.preferredURL(for: item.id),
                durationSeconds: parseDuration(duration),
                viewCount: item.statistics?.viewCount.flatMap(Int.init)
            )
        }
    }

    static func mergeVideos(_ videos: [YouTubePlaylistVideo], preferredOrder: [String]) -> [YouTubePlaylistVideo] {
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
