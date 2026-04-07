import Foundation

enum BasicGUIScreen: Equatable {
    case home
    case channelList(sortDescriptor: ChannelBrowseSortDescriptor)
    case allVideos
    case keywordSearchResults(keyword: String)
    case remoteKeywordSearchResults(keyword: String)
    case channelRegistration
    case channelVideos(context: ChannelVideosRouteContext)
}

enum BasicGUIBrowsePresentation: String, Equatable {
    case compact
    case split
}

enum BasicGUIRouteAssembly {
    static func screen(for route: MaintenanceRoute) -> BasicGUIScreen {
        switch route {
        case let .channelList(sortDescriptor):
            .channelList(sortDescriptor: sortDescriptor)
        case .allVideos:
            .allVideos
        case let .keywordSearchResults(keyword):
            .keywordSearchResults(keyword: keyword)
        case let .remoteKeywordSearchResults(keyword):
            .remoteKeywordSearchResults(keyword: keyword)
        case .channelRegistration:
            .channelRegistration
        case let .channelVideos(context):
            .channelVideos(context: context)
        }
    }
}

enum BasicGUILayoutBranching {
    static func channelBrowsePresentation(for layout: AppLayout) -> BasicGUIBrowsePresentation {
        layout.usesSplitChannelBrowser ? .split : .compact
    }

    static func remoteSearchPresentation(for layout: AppLayout) -> BasicGUIBrowsePresentation {
        layout.usesSplitChannelBrowser ? .split : .compact
    }
}
