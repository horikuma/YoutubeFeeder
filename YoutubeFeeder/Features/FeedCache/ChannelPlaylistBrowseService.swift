import Foundation

struct ChannelPlaylistBrowseService {
    let playlistService: YouTubePlaylistService

    var isConfigured: Bool {
        playlistService.isConfigured
    }

    func loadPlaylists(channelID: String, limit: Int = 50) async throws -> [PlaylistBrowseItem] {
        let playlists = try await playlistService.fetchPlaylists(channelID: channelID, limit: limit)
        var playlistItems: [PlaylistBrowseItem] = []
        playlistItems.reserveCapacity(playlists.count)
        for playlist in playlists {
            let firstVideoPage = try await playlistService.fetchPlaylistVideosPage(
                playlistID: playlist.id,
                pageToken: nil,
                limit: 1
            )
            playlistItems.append(
                mapPlaylistItem(
                    playlist,
                    firstVideoThumbnailURL: firstVideoPage.videos.first?.thumbnailURL
                )
            )
        }
        return sortPlaylists(playlistItems)
    }

    func loadPlaylistVideosPage(
        playlistID: String,
        pageToken: String? = nil,
        limit: Int = 50
    ) async throws -> PlaylistBrowseVideosPage {
        let page = try await playlistService.fetchPlaylistVideosPage(
            playlistID: playlistID,
            pageToken: pageToken,
            limit: limit
        )
        return PlaylistBrowseVideosPage(
            playlistID: page.playlistID,
            videos: page.videos.map(mapPlaylistVideo),
            totalCount: page.totalCount,
            fetchedAt: page.fetchedAt,
            nextPageToken: page.nextPageToken
        )
    }

    func continuousPlayURL(playlistID: String) -> URL? {
        playlistService.continuousPlayURL(playlistID: playlistID)
    }

    private func sortPlaylists(_ playlists: [PlaylistBrowseItem]) -> [PlaylistBrowseItem] {
        playlists.sorted { lhs, rhs in
            switch (lhs.publishedAt, rhs.publishedAt) {
            case let (left?, right?) where left != right:
                return left > right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return lhs.title == rhs.title ? lhs.id < rhs.id : lhs.title < rhs.title
            }
        }
    }

    private func mapPlaylistItem(
        _ item: YouTubePlaylistListItem,
        firstVideoThumbnailURL: URL?
    ) -> PlaylistBrowseItem {
        PlaylistBrowseItem(
            id: item.id,
            playlistID: item.id,
            channelID: item.channelID,
            channelTitle: item.channelTitle,
            title: item.title,
            description: item.description,
            publishedAt: item.publishedAt,
            itemCount: item.itemCount,
            thumbnailURL: item.thumbnailURL,
            firstVideoThumbnailURL: firstVideoThumbnailURL
        )
    }

    private func mapPlaylistVideo(_ video: YouTubePlaylistVideo) -> PlaylistBrowseVideo {
        PlaylistBrowseVideo(
            id: video.id,
            channelID: video.channelID,
            channelTitle: video.channelTitle,
            title: video.title,
            publishedAt: video.publishedAt,
            videoURL: video.videoURL,
            thumbnailURL: video.thumbnailURL,
            durationSeconds: video.durationSeconds,
            viewCount: video.viewCount
        )
    }
}
