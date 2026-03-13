import SwiftUI

struct HomeScreenView: View {
    @ObservedObject var coordinator: FeedCacheCoordinator
    let layout: AppLayout
    let diagnostics: StartupDiagnostics
    let navigationPath: Binding<NavigationPath>
    @State private var didRunAutoRefresh = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: layout.sectionSpacing) {
                if AppLaunchMode.current.usesMockData {
                    UITestMarker(
                        identifier: "test.manualRefreshCount",
                        value: "\(coordinator.manualRefreshCount)"
                    )
                }

                Text("ホーム")
                    .font(layout.isPad ? .system(size: 38, weight: .black, design: .rounded) : .largeTitle.bold())
                    .accessibilityIdentifier("screen.home")

                navigationSection
            }
            .frame(maxWidth: layout.contentWidth ?? .infinity, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable {
            await coordinator.refreshCacheManually()
        }
        .onAppear {
            diagnostics.mark("maintenanceShown")
        }
        .task {
            guard AppLaunchMode.current.autoRefreshOnLaunch else { return }
            guard !didRunAutoRefresh else { return }
            didRunAutoRefresh = true
            await coordinator.refreshCacheManually()
        }
    }

    private var navigationSection: some View {
        LazyVGrid(columns: layoutColumns, spacing: 16) {
            NavigationLink(value: MaintenanceRoute.channelList) {
                MetricTile(
                    title: "チャンネル",
                    value: "",
                    detail: "タップでチャンネル一覧"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("nav.channels")

            NavigationLink(value: MaintenanceRoute.allVideos) {
                MetricTile(
                    title: "動画",
                    value: "",
                    detail: "タップで動画一覧"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("nav.videos")
        }
    }

    private var layoutColumns: [GridItem] {
        if layout.isPad {
            return [
                GridItem(.flexible(), spacing: 16, alignment: .top),
                GridItem(.flexible(), spacing: 16, alignment: .top),
            ]
        }

        return [GridItem(.flexible(), spacing: 16, alignment: .top)]
    }
}
