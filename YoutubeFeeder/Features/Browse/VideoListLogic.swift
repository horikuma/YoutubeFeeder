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

    mutating func requestRemoval(for item: ChannelBrowseItem, source: String = "unspecified") {
        pendingChannelRemoval = PendingChannelRemoval(channelID: item.channelID, channelTitle: item.channelTitle)
        AppConsoleLogger.browseTileInteraction.info(
            "channel_removal_pending_requested",
            metadata: [
                "source": source,
                "channelID": item.channelID,
                "channelTitle": item.channelTitle
            ]
        )
    }

    mutating func clearPendingRemoval(reason: String = "unspecified") {
        if let pendingChannelRemoval {
            AppConsoleLogger.browseTileInteraction.info(
                "channel_removal_pending_cleared",
                metadata: [
                    "reason": reason,
                    "channelID": pendingChannelRemoval.channelID,
                    "channelTitle": pendingChannelRemoval.channelTitle
                ]
            )
        }
        pendingChannelRemoval = nil
    }

    func logPendingRemovalConfirmation(source: String) {
        guard let pendingChannelRemoval else { return }
        AppConsoleLogger.browseTileInteraction.info(
            "channel_removal_dialog_confirmed",
            metadata: [
                "source": source,
                "channelID": pendingChannelRemoval.channelID,
                "channelTitle": pendingChannelRemoval.channelTitle
            ]
        )
    }

    mutating func applyRemovalFeedback(_ feedback: ChannelRemovalFeedback) {
        removalFeedback = feedback
    }
}
