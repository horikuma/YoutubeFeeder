import Foundation
import SwiftUI

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

    var usesSplitLayout: Bool {
        self == .split
    }
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

struct BasicGUIRootView: View {
    let coordinator: FeedCacheCoordinator
    let openVideo: (CachedVideo) -> Void
    let layout: AppLayout
    let diagnostics: StartupDiagnostics
    @Binding var navigationPath: NavigationPath

    var body: some View {
        NavigationStack(path: $navigationPath) {
            BasicGUIHomeScreen(
                coordinator: coordinator,
                layout: layout,
                diagnostics: diagnostics,
                navigationPath: $navigationPath
            )
            .navigationDestination(for: MaintenanceRoute.self) { route in
                BasicGUIDestinationView(
                    route: route,
                    coordinator: coordinator,
                    openVideo: openVideo,
                    path: $navigationPath,
                    layout: layout
                )
            }
        }
    }
}

struct BasicGUIHomeScreen: View {
    let coordinator: FeedCacheCoordinator
    let layout: AppLayout
    let diagnostics: StartupDiagnostics
    @Binding var navigationPath: NavigationPath

    var body: some View {
        HomeScreenView(
            coordinator: coordinator,
            layout: layout,
            diagnostics: diagnostics,
            navigationPath: $navigationPath
        )
    }
}

struct BasicGUIChannelBrowseScreen: View {
    let coordinator: FeedCacheCoordinator
    let openVideo: (CachedVideo) -> Void
    @Binding var path: NavigationPath
    let layout: AppLayout
    let sortDescriptor: ChannelBrowseSortDescriptor

    var body: some View {
        ChannelBrowseView(
            coordinator: coordinator,
            openVideo: openVideo,
            path: $path,
            layout: layout,
            sortDescriptor: sortDescriptor,
            presentation: BasicGUILayoutBranching.channelBrowsePresentation(for: layout)
        )
    }
}

struct BasicGUIRemoteSearchScreen: View {
    let keyword: String
    let coordinator: FeedCacheCoordinator
    let openVideo: (CachedVideo) -> Void
    @Binding var path: NavigationPath
    let layout: AppLayout
    let presentationMode: RemoteSearchPresentationMode

    init(
        keyword: String,
        coordinator: FeedCacheCoordinator,
        openVideo: @escaping (CachedVideo) -> Void,
        path: Binding<NavigationPath>,
        layout: AppLayout,
        presentationMode: RemoteSearchPresentationMode = .visible
    ) {
        self.keyword = keyword
        self.coordinator = coordinator
        self.openVideo = openVideo
        _path = path
        self.layout = layout
        self.presentationMode = presentationMode
    }

    var body: some View {
        RemoteKeywordSearchResultsView(
            keyword: keyword,
            coordinator: coordinator,
            openVideo: openVideo,
            path: $path,
            layout: layout,
            browsePresentation: BasicGUILayoutBranching.remoteSearchPresentation(for: layout),
            presentationMode: presentationMode
        )
    }
}

private struct BasicGUIDestinationView: View {
    let route: MaintenanceRoute
    let coordinator: FeedCacheCoordinator
    let openVideo: (CachedVideo) -> Void
    @Binding var path: NavigationPath
    let layout: AppLayout

    var body: some View {
        switch BasicGUIRouteAssembly.screen(for: route) {
        case let .channelList(sortDescriptor):
            BasicGUIChannelBrowseScreen(
                coordinator: coordinator,
                openVideo: openVideo,
                path: $path,
                layout: layout,
                sortDescriptor: sortDescriptor
            )
        case .allVideos:
            AllVideosView(coordinator: coordinator, openVideo: openVideo, path: $path, layout: layout)
        case let .keywordSearchResults(keyword):
            KeywordSearchResultsView(keyword: keyword, coordinator: coordinator, openVideo: openVideo, path: $path, layout: layout)
        case let .remoteKeywordSearchResults(keyword):
            BasicGUIRemoteSearchScreen(
                keyword: keyword,
                coordinator: coordinator,
                openVideo: openVideo,
                path: $path,
                layout: layout
            )
        case .channelRegistration:
            ChannelRegistrationView(coordinator: coordinator)
        case let .channelVideos(context):
            ChannelVideosView(context: context, coordinator: coordinator, openVideo: openVideo, path: $path, layout: layout)
        case .home:
            BasicGUIHomeScreen(
                coordinator: coordinator,
                layout: layout,
                diagnostics: StartupDiagnostics.shared,
                navigationPath: $path
            )
        }
    }
}
