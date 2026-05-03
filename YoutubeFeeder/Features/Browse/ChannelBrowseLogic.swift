import Foundation

struct PendingChannelRemoval: Identifiable, Hashable {
    let channelID: String
    let channelTitle: String

    var id: String { channelID }
}

struct ChannelBrowseLogic: Hashable {
    var items: [ChannelBrowseItem] = []
    var pendingChannelRemoval: PendingChannelRemoval?
    var removalFeedback: ChannelRemovalFeedback?
    var selectedChannelID: String?
    var videosByChannelID: [String: [CachedVideo]] = [:]
    var loadingChannelIDs: Set<String> = []
    var selectedChannelRefreshSource: String?
    var browseDisplayModeByChannelID: [String: ChannelBrowseDisplayMode] = [:]
    var playlistsByChannelID: [String: [PlaylistBrowseItem]] = [:]
    var selectedPlaylistIDByChannelID: [String: String] = [:]
    var playlistVideosByPlaylistID: [String: PlaylistBrowseVideosPage] = [:]

    mutating func setItems(_ items: [ChannelBrowseItem]) {
        let previousItems = self.items
        self.items = items
        if let selectedChannelID, !items.contains(where: { $0.channelID == selectedChannelID }) {
            self.selectedChannelID = nil
            loadingChannelIDs.remove(selectedChannelID)
            videosByChannelID[selectedChannelID] = nil
            browseDisplayModeByChannelID[selectedChannelID] = nil
            playlistsByChannelID[selectedChannelID] = nil
            selectedPlaylistIDByChannelID[selectedChannelID] = nil
            selectedChannelRefreshSource = nil
            return
        }

        guard let selectedChannelID else { return }
        guard let previousSelectedItem = previousItems.first(where: { $0.channelID == selectedChannelID }) else { return }
        guard let currentSelectedItem = items.first(where: { $0.channelID == selectedChannelID }) else { return }
        if previousSelectedItem != currentSelectedItem {
            loadingChannelIDs.remove(selectedChannelID)
            videosByChannelID[selectedChannelID] = nil
            selectedChannelRefreshSource = "channel_list_update"
        }
    }

    mutating func requestRemoval(for item: ChannelBrowseItem) {
        pendingChannelRemoval = PendingChannelRemoval(channelID: item.channelID, channelTitle: item.channelTitle)
    }

    mutating func clearPendingRemoval() {
        pendingChannelRemoval = nil
    }

    mutating func applyRemovalFeedback(_ feedback: ChannelRemovalFeedback) {
        removalFeedback = feedback
    }

    mutating func selectChannel(_ channelID: String) {
        selectedChannelID = channelID
    }

    mutating func setDisplayMode(_ mode: ChannelBrowseDisplayMode, for channelID: String) {
        browseDisplayModeByChannelID[channelID] = mode
    }

    func displayMode(for channelID: String) -> ChannelBrowseDisplayMode {
        browseDisplayModeByChannelID[channelID] ?? .videos
    }

    mutating func refreshPlaylists(_ playlists: [PlaylistBrowseItem], for channelID: String) {
        playlistsByChannelID[channelID] = playlists
        if let selectedPlaylistID = selectedPlaylistIDByChannelID[channelID],
           !playlists.contains(where: { $0.playlistID == selectedPlaylistID }) {
            selectedPlaylistIDByChannelID[channelID] = nil
        }
    }

    func playlists(for channelID: String) -> [PlaylistBrowseItem] {
        playlistsByChannelID[channelID] ?? []
    }

    func hasLoadedPlaylists(for channelID: String) -> Bool {
        playlistsByChannelID[channelID] != nil
    }

    mutating func selectPlaylist(_ playlistID: String?, for channelID: String) {
        let normalizedPlaylistID = playlistID?.trimmingCharacters(in: .whitespacesAndNewlines)
        selectedPlaylistIDByChannelID[channelID] = normalizedPlaylistID?.isEmpty == true ? nil : normalizedPlaylistID
    }

    func selectedPlaylistID(for channelID: String) -> String? {
        selectedPlaylistIDByChannelID[channelID]
    }

    func selectedPlaylist(for channelID: String) -> PlaylistBrowseItem? {
        guard let selectedPlaylistID = selectedPlaylistID(for: channelID) else { return nil }
        return playlists(for: channelID).first(where: { $0.playlistID == selectedPlaylistID })
    }

    func selectedPlaylistTitle(for channelID: String) -> String {
        selectedPlaylist(for: channelID)?.title ?? "プレイリスト未選択"
    }

    mutating func refreshPlaylistVideos(_ page: PlaylistBrowseVideosPage) {
        playlistVideosByPlaylistID[page.playlistID] = page
    }

    func playlistVideos(for playlistID: String) -> [PlaylistBrowseVideo] {
        playlistVideosByPlaylistID[playlistID]?.videos ?? []
    }

    func playlistVideosPage(for playlistID: String) -> PlaylistBrowseVideosPage? {
        playlistVideosByPlaylistID[playlistID]
    }

    func selectedPlaylistVideos(for channelID: String) -> [PlaylistBrowseVideo] {
        guard let selectedPlaylistID = selectedPlaylistID(for: channelID) else { return [] }
        return playlistVideos(for: selectedPlaylistID)
    }

    mutating func applyDefaultSelectionIfNeeded() -> String? {
        if let selectedChannelID, items.contains(where: { $0.channelID == selectedChannelID }) {
            return selectedChannelID
        }
        guard let firstChannelID = items.first?.channelID else {
            selectedChannelID = nil
            return nil
        }
        selectedChannelID = firstChannelID
        return firstChannelID
    }

    mutating func beginLoadingVideos(for channelID: String) -> Bool {
        guard videosByChannelID[channelID] == nil else { return false }
        guard !loadingChannelIDs.contains(channelID) else { return false }
        loadingChannelIDs.insert(channelID)
        return true
    }

    mutating func finishLoadingVideos(_ videos: [CachedVideo], for channelID: String) {
        loadingChannelIDs.remove(channelID)
        if videosByChannelID[channelID] == nil {
            videosByChannelID[channelID] = videos
        }
    }

    mutating func appendLoadingVideos(_ videos: [CachedVideo], for channelID: String) {
        loadingChannelIDs.remove(channelID)
        guard !videos.isEmpty else { return }
        let existingIDs = Set(videosByChannelID[channelID]?.map(\.id) ?? [])
        let appendedVideos = videos.filter { !existingIDs.contains($0.id) }
        guard !appendedVideos.isEmpty else { return }
        videosByChannelID[channelID, default: []].append(contentsOf: appendedVideos)
    }

    mutating func refreshSelectedChannelVideos(_ videos: [CachedVideo]) {
        guard let selectedChannelID else { return }
        videosByChannelID[selectedChannelID] = videos
    }

    mutating func appendSelectedChannelVideos(_ videos: [CachedVideo]) {
        guard let selectedChannelID else { return }
        let existingIDs = Set(videosByChannelID[selectedChannelID]?.map(\.id) ?? [])
        let appendedVideos = videos.filter { !existingIDs.contains($0.id) }
        guard !appendedVideos.isEmpty else { return }
        videosByChannelID[selectedChannelID, default: []].append(contentsOf: appendedVideos)
    }

    func videosForSelectedChannel() -> [CachedVideo] {
        guard let selectedChannelID else { return [] }
        return videosByChannelID[selectedChannelID] ?? []
    }

    func selectedTitle() -> String {
        guard let selectedChannelID else { return "チャンネル未選択" }
        return items.first(where: { $0.channelID == selectedChannelID })?.channelTitle ?? selectedChannelID
    }
}

struct ChannelBrowseTipsSummary: Hashable {
    let countText: String
    let sortText: String
    let primaryHint: String
    let secondaryHint: String

    static func build(items: [ChannelBrowseItem], sortDescriptor: ChannelBrowseSortDescriptor) -> Self {
        Self(
            countText: "\(items.count)件",
            sortText: sortDescriptor.shortLabel,
            primaryHint: "タップで動画一覧",
            secondaryHint: AppInteractionPlatform.current.menuInteractionHint
        )
    }
}
