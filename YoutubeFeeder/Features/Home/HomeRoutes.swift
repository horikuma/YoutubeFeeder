import Foundation

struct ChannelVideosRouteContext: Hashable {
    let channelID: String
    let preferredChannelTitle: String?
    let selectedVideoID: String?
    let prefersAutomaticRefresh: Bool

    init(
        channelID: String,
        preferredChannelTitle: String? = nil,
        selectedVideoID: String? = nil,
        prefersAutomaticRefresh: Bool = false
    ) {
        self.channelID = channelID
        self.preferredChannelTitle = preferredChannelTitle
        self.selectedVideoID = selectedVideoID
        self.prefersAutomaticRefresh = prefersAutomaticRefresh
    }
}

enum MaintenanceRoute: Hashable {
    case channelList(ChannelBrowseSortDescriptor)
    case allVideos
    case keywordSearchResults(String)
    case remoteKeywordSearchResults(String)
    case channelRegistration
    case channelVideos(ChannelVideosRouteContext)
}
