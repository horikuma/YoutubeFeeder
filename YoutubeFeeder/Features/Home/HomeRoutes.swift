import Foundation

enum ChannelVideosRouteSource: String, Hashable {
    case channelBrowse
    case localSearch
    case remoteSearch
}

struct ChannelVideosRouteContext: Hashable {
    let channelID: String
    let preferredChannelTitle: String?
    let selectedVideoID: String?
    let prefersAutomaticRefresh: Bool
    let routeSource: ChannelVideosRouteSource

    init(
        channelID: String,
        preferredChannelTitle: String? = nil,
        selectedVideoID: String? = nil,
        prefersAutomaticRefresh: Bool = false,
        routeSource: ChannelVideosRouteSource = .channelBrowse
    ) {
        self.channelID = channelID
        self.preferredChannelTitle = preferredChannelTitle
        self.selectedVideoID = selectedVideoID
        self.prefersAutomaticRefresh = prefersAutomaticRefresh
        self.routeSource = routeSource
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
