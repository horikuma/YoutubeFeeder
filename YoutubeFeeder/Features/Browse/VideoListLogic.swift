struct VideoListLogic: Hashable {
    var videos: [CachedVideo] = []
    var isAutomaticRefreshInProgress = false
    var pendingChannelRemoval: PendingChannelRemoval?
    var removalFeedback: ChannelRemovalFeedback?

    mutating func beginAutomaticRefresh() {
        isAutomaticRefreshInProgress = true
    }

    mutating func setVideos(_ videos: [CachedVideo]) {
        self.videos = videos
        isAutomaticRefreshInProgress = false
    }

    mutating func finishAutomaticRefresh(_ videos: [CachedVideo]) {
        self.videos = videos
        isAutomaticRefreshInProgress = false
    }

    mutating func appendVideos(_ videos: [CachedVideo]) {
        guard !videos.isEmpty else { return }
        let existingIDs = Set(self.videos.map(\.id))
        let appendedVideos = videos.filter { !existingIDs.contains($0.id) }
        guard !appendedVideos.isEmpty else { return }
        self.videos.append(contentsOf: appendedVideos)
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
}
