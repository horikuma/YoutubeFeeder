import SwiftUI

struct HomeScreenView: View {
    @ObservedObject var coordinator: FeedCacheCoordinator
    let layout: AppLayout
    let diagnostics: StartupDiagnostics
    let navigationPath: Binding<NavigationPath>
    @State private var didRunAutoRefresh = false

    var body: some View {
        let progress = coordinator.progress

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

                if layout.isPad {
                    HStack(alignment: .top, spacing: 18) {
                        progressSection(progress: progress)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        summarySection(progress: progress)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    progressSection(progress: progress)
                    summarySection(progress: progress)
                }
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
        .overlay(alignment: .topTrailing) {
            if AppLaunchMode.current.usesMockData {
                ZStack(alignment: .topTrailing) {
                    Button("refresh") {
                        Task {
                            await coordinator.refreshCacheManually()
                        }
                    }
                    .frame(width: 44, height: 44)
                    .padding(8)
                    .opacity(0.01)
                    .accessibilityIdentifier("test.refresh")

                }
            }
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

    private func progressSection(progress: CacheProgress) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            feedRefreshCard(coordinator.refreshProgress.checkStage)

            LazyVGrid(columns: layoutColumns, spacing: 16) {
                NavigationLink(value: MaintenanceRoute.allVideos) {
                    MetricTile(
                        title: "動画",
                        value: "\(progress.cachedVideos)",
                        detail: "タップで動画一覧"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("nav.videos")
            }
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

    @ViewBuilder
    private func summarySection(progress: CacheProgress) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ChannelStateLiveCard(
                title: "キャッシュ済みチャンネル",
                value: "\(progress.cachedChannels) / \(progress.totalChannels)",
                detail: "ホームを下に引っ張ると更新"
            )

            ChannelStateLiveCard(
                title: "キャッシュ済み動画",
                value: "\(progress.cachedVideos)",
                detail: "サムネイル \(progress.cachedThumbnails) 件"
            )

            if let lastError = progress.lastError {
                ChannelStateLiveCard(
                    title: "最新エラー",
                    value: lastError,
                    detail: "次のチャンネル取得は継続します"
                )
            }
        }
    }

    private func feedRefreshCard(_ stage: RefreshStageProgress) -> some View {
        let remaining = max(stage.total - stage.completed, 0)

        return ChannelStateLiveCard(
            title: stage.title,
            value: "残り \(remaining) チャンネル",
            detail: stage.activeCalls > 0 ? "同時取得 \(stage.activeCalls) / 3" : "ホームを下に引っ張ると更新"
        )
        .accessibilityIdentifier("progress.stage.\(stage.title)")
    }
}
