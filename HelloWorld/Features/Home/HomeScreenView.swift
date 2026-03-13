import SwiftUI

struct HomeScreenView: View {
    @ObservedObject var coordinator: FeedCacheCoordinator
    let layout: AppLayout
    let diagnostics: StartupDiagnostics
    let navigationPath: Binding<NavigationPath>

    var body: some View {
        let progress = coordinator.progress

        ScrollView {
            VStack(alignment: .leading, spacing: layout.sectionSpacing) {
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

                    UITestMarker(
                        identifier: "test.manualRefreshCount",
                        value: "\(coordinator.manualRefreshCount)"
                    )
                }
            }
        }
        .onAppear {
            diagnostics.mark("maintenanceShown")
        }
    }

    private func progressSection(progress: CacheProgress) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            stageProgressCard(coordinator.refreshProgress.checkStage)
            stageProgressCard(coordinator.refreshProgress.fetchStage)
            stageProgressCard(coordinator.refreshProgress.thumbnailStage)

            LazyVGrid(columns: layoutColumns, spacing: 16) {
                NavigationLink(value: MaintenanceRoute.channelList) {
                    MetricTile(
                        title: "チャンネル",
                        value: "\(progress.cachedChannels) / \(progress.totalChannels)",
                        detail: "タップでチャンネル一覧"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("nav.channels")

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

    private func stageProgressCard(_ stage: RefreshStageProgress) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(stage.title)
                    .font(.headline)
                Spacer()
                Text("\(stage.callsPerSecond)/秒")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(stage.completed), total: Double(max(stage.total, 1)))

            HStack {
                Text("\(stage.completed) / \(stage.total)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("実行中 \(stage.activeCalls)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityIdentifier("progress.stage.\(stage.title)")
    }
}
