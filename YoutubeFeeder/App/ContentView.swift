import SwiftUI

struct ContentView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var coordinator: FeedCacheCoordinator
    @State private var hasEnteredMaintenance = false
    @State private var hasPreparedMaintenance = false
    @State private var hasAppliedInitialUITestRoute = false
    @State private var navigationPath = NavigationPath()
    @ObservedObject private var diagnostics = StartupDiagnostics.shared
    private let dependencies: FeedCacheDependencies

    init() {
        let dependencies = FeedCacheDependencies.live()
        self.dependencies = dependencies
        _coordinator = StateObject(
            wrappedValue: FeedCacheCoordinator(
                channels: ChannelRegistryStore.loadAllChannelIDs(),
                dependencies: dependencies
            )
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = AppLayout.current(
                size: geometry.size,
                horizontalSizeClass: horizontalSizeClass
            )

            Group {
                if hasEnteredMaintenance {
                    NavigationStack(path: $navigationPath) {
                        HomeScreenView(
                            coordinator: coordinator,
                            layout: layout,
                            diagnostics: diagnostics,
                            navigationPath: $navigationPath
                        )
                        .navigationDestination(for: MaintenanceRoute.self) { route in
                            switch route {
                            case let .channelList(sortDescriptor):
                                ChannelBrowseView(
                                    coordinator: coordinator,
                                    openVideo: openVideo,
                                    path: $navigationPath,
                                    layout: layout,
                                    sortDescriptor: sortDescriptor
                                )
                            case .allVideos:
                                AllVideosView(coordinator: coordinator, openVideo: openVideo, path: $navigationPath, layout: layout)
                            case let .keywordSearchResults(keyword):
                                KeywordSearchResultsView(keyword: keyword, coordinator: coordinator, openVideo: openVideo, path: $navigationPath, layout: layout)
                            case let .remoteKeywordSearchResults(keyword):
                                RemoteKeywordSearchResultsView(keyword: keyword, coordinator: coordinator, openVideo: openVideo, path: $navigationPath, layout: layout)
                            case .channelRegistration:
                                ChannelRegistrationView(coordinator: coordinator)
                            case let .channelVideos(context):
                                ChannelVideosView(context: context, coordinator: coordinator, openVideo: openVideo, path: $navigationPath, layout: layout)
                            }
                        }
                    }
                } else {
                    LaunchScreenView()
                }
            }
            .overlay(alignment: .topTrailing) {
                if AppInteractionPlatform.current.usesMenuCommandForRefresh {
                    UITestAsyncActionTrigger(identifier: "test.refresh.command") {
                        await RefreshCommandCenter.shared.performCurrentRefresh()
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 8)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .attachDiagnosticsProbe()
        .task(priority: .userInitiated) {
            guard !hasPreparedMaintenance else { return }
            hasPreparedMaintenance = true
            let startedAt = Date()
            AppConsoleLogger.appLifecycle.info("bootstrap_start")
            await coordinator.bootstrapMaintenance()
            diagnostics.mark("bootstrapLoaded")
            AppConsoleLogger.appLifecycle.notice(
                "bootstrap_complete",
                metadata: ["elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)]
            )
            withAnimation(.easeInOut(duration: 0.2)) {
                hasEnteredMaintenance = true
            }
        }
        .task(id: hasEnteredMaintenance) {
            guard hasEnteredMaintenance else { return }
            diagnostics.mark("maintenanceEntered")
            AppConsoleLogger.appLifecycle.info("maintenance_entered")

            guard !hasAppliedInitialUITestRoute else { return }
            guard let initialRoute = AppLaunchMode.current.initialUITestRoute else { return }

            hasAppliedInitialUITestRoute = true
            switch initialRoute {
            case .allVideos:
                navigationPath.append(MaintenanceRoute.allVideos)
            case .channelSearchResults:
                navigationPath.append(MaintenanceRoute.remoteKeywordSearchResults("ゆっくり実況"))
            case .channelRegistration:
                navigationPath.append(MaintenanceRoute.channelRegistration)
            case .channelList:
                navigationPath.append(MaintenanceRoute.channelList(.default))
            }
        }
    }

    private func openVideo(_ video: CachedVideo) {
        guard let webURL = video.videoURL else { return }

        let appURL = URL(string: "youtube://watch?v=\(video.id)")!
        openURL(appURL) { accepted in
            if !accepted {
                openURL(webURL)
            }
        }
    }
}
