import Foundation

struct ChannelPlaylistBrowseService {
    let playlistService: YouTubePlaylistService

    var isConfigured: Bool {
        playlistService.isConfigured
    }

    func loadPlaylists(channelID: String, limit: Int = 50) async throws -> [YouTubePlaylistListItem] {
        let playlists = try await playlistService.fetchPlaylists(channelID: channelID, limit: limit)
        return sortPlaylists(playlists)
    }

    func loadPlaylistVideosPage(
        playlistID: String,
        pageToken: String? = nil,
        limit: Int = 50
    ) async throws -> YouTubePlaylistVideosPage {
        try await playlistService.fetchPlaylistVideosPage(
            playlistID: playlistID,
            pageToken: pageToken,
            limit: limit
        )
    }

    func continuousPlayURL(playlistID: String) -> URL? {
        playlistService.continuousPlayURL(playlistID: playlistID)
    }

    private func sortPlaylists(_ playlists: [YouTubePlaylistListItem]) -> [YouTubePlaylistListItem] {
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
}
