import SwiftUI

struct ContentView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var coordinator: FeedCacheCoordinator
    @State private var hasEnteredMaintenance = false
    @State private var hasPreparedMaintenance = false
    @State private var hasAppliedInitialUITestRoute = false
    @State private var navigationPath = NavigationPath()
    @State private var webViewURL: URL?
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

            contentView(layout: layout, geometry: geometry)
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
        if AppInteractionPlatform.current == .desktop {
            webViewURL = webURL
        } else {
            let appURL = URL(string: "youtube://watch?v=\(video.id)")!
            openURL(appURL) { accepted in
                if !accepted {
                    openURL(webURL)
                }
            }
        }
    }

    @ViewBuilder
    private func contentView(layout: AppLayout, geometry: GeometryProxy) -> some View {
        if AppInteractionPlatform.current == .desktop {
            HStack(spacing: 0) {
                Group {
                    if hasEnteredMaintenance {
                        BasicGUIRootView(
                            coordinator: coordinator,
                            openVideo: openVideo,
                            layout: layout,
                            diagnostics: diagnostics,
                            navigationPath: $navigationPath
                        )
                    } else {
                        LaunchScreenView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                EmbeddedWebView(url: $webViewURL)
                    .frame(width: max(geometry.size.width * 0.42, 360))
            }
        } else {
            Group {
                if hasEnteredMaintenance {
                    BasicGUIRootView(
                        coordinator: coordinator,
                        openVideo: openVideo,
                        layout: layout,
                        diagnostics: diagnostics,
                        navigationPath: $navigationPath
                    )
                } else {
                    LaunchScreenView()
                }
            }
        }
    }
}
