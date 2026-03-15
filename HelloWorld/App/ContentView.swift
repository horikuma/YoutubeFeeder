//
//  ContentView.swift
//  HelloWorld
//
//  Created by 高下彰実 on 2026/03/11.
//

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

    init() {
        _coordinator = StateObject(wrappedValue: FeedCacheCoordinator(channels: ChannelRegistryStore.loadPersistedOrSeededChannelIDs()))
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
                                ChannelBrowseListView(
                                    coordinator: coordinator,
                                    openVideo: openVideo,
                                    path: $navigationPath,
                                    layout: layout,
                                    sortDescriptor: sortDescriptor
                                )
                            case .allVideos:
                                AllVideosView(coordinator: coordinator, openVideo: openVideo, path: $navigationPath, layout: layout)
                            case .channelRegistration:
                                ChannelRegistrationView(coordinator: coordinator)
                            case let .channelVideos(channelID):
                                ChannelVideosView(channelID: channelID, coordinator: coordinator, openVideo: openVideo, path: $navigationPath, layout: layout)
                            }
                        }
                    }
                } else {
                    LaunchScreenView()
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .attachDiagnosticsProbe()
        .task(priority: .userInitiated) {
            guard !hasPreparedMaintenance else { return }
            hasPreparedMaintenance = true
            await coordinator.bootstrapMaintenance()
            diagnostics.mark("bootstrapLoaded")
            withAnimation(.easeInOut(duration: 0.2)) {
                hasEnteredMaintenance = true
            }
        }
        .task(id: hasEnteredMaintenance) {
            guard hasEnteredMaintenance else { return }
            diagnostics.mark("maintenanceEntered")

            guard !hasAppliedInitialUITestRoute else { return }
            guard let initialRoute = AppLaunchMode.current.initialUITestRoute else { return }

            hasAppliedInitialUITestRoute = true
            switch initialRoute {
            case .allVideos:
                navigationPath.append(MaintenanceRoute.allVideos)
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
