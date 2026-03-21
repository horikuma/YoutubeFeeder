import SwiftUI

struct ChannelVideosView: View {
    private static let automaticRefreshIndicatorMinimumDuration: Duration = .milliseconds(400)
    private static let automaticRefreshIndicatorMockDuration: Duration = .seconds(2)

    let context: ChannelVideosRouteContext
    let coordinator: FeedCacheCoordinator
    let openVideo: (CachedVideo) -> Void
    @Binding var path: NavigationPath
    let layout: AppLayout

    @State private var videos: [CachedVideo] = []
    @State private var isAutomaticRefreshInProgress = false
    @State private var pendingChannelRemoval: PendingChannelRemoval?
    @State private var removalFeedback: ChannelRemovalFeedback?

    var body: some View {
        InteractiveListView(
            title: channelTitle,
            subtitle: "このチャンネルの動画を新しい順に最大50件表示",
            coordinator: coordinator,
            path: $path,
            layout: layout,
            onRefresh: {
                RuntimeDiagnostics.shared.record(
                    "channel_refresh_gesture",
                    detail: "チャンネル動画一覧で下スワイプ更新",
                    metadata: [
                        "channelID": context.channelID,
                        "screen": "channelVideos"
                    ]
                )
                await coordinator.refreshChannelManually(context.channelID)
                await reloadVideos()
                RuntimeDiagnostics.shared.record(
                    "channel_refresh_view_reload_finished",
                    detail: "チャンネル動画一覧リロード完了",
                    metadata: [
                        "channelID": context.channelID,
                        "videoCount": String(videos.count)
                    ]
                )
            }
        ) {
            if AppLaunchMode.current.usesMockData {
                UITestMarker(
                    identifier: "screen.channelVideos.loaded",
                    value: videos.first?.id ?? "none"
                )
                UITestMarker(
                    identifier: "test.channelRefreshTarget",
                    value: coordinator.lastManualChannelRefreshID ?? "none"
                )
                UITestMarker(
                    identifier: "channel.autoRefreshState",
                    value: isAutomaticRefreshInProgress ? "loading" : "idle"
                )
            }

            if videos.isEmpty {
                MetricTile(title: "動画一覧", value: "まだありません", detail: "このチャンネルのキャッシュがあるとここに表示します")
            } else {
                LazyVGrid(columns: layout.listColumns, spacing: layout.isPad ? 20 : 14) {
                    ForEach(Array(videos.enumerated()), id: \.element.id) { offset, video in
                        VideoTile(
                            video: video,
                            tapAction: nil,
                            openVideoAction: {
                                openVideo(video)
                            },
                            removeChannel: {
                                pendingChannelRemoval = PendingChannelRemoval(
                                    channelID: video.channelID,
                                    channelTitle: video.channelTitle.isEmpty ? video.channelID : video.channelTitle
                                )
                            },
                            index: offset + 1
                        )
                    }
                }
            }
        }
        .task {
            await reloadVideos()
        }
        .overlay(alignment: .top) {
            if isAutomaticRefreshInProgress {
                VStack(spacing: 0) {
                    ProgressView()
                        .accessibilityIdentifier("channel.autoRefreshIndicator")
                        .padding(.top, 8)
                }
            }
        }
        .confirmationDialog(
            pendingChannelRemoval.map { "\($0.channelTitle)を削除しますか" } ?? "",
            isPresented: Binding(
                get: { pendingChannelRemoval != nil },
                set: { if !$0 { pendingChannelRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("チャンネルを削除", role: .destructive) {
                guard let pendingChannelRemoval else { return }
                Task {
                    if let feedback = await coordinator.removeChannel(pendingChannelRemoval.channelID) {
                        await MainActor.run {
                            removalFeedback = feedback
                        }
                    }
                }
                self.pendingChannelRemoval = nil
            }
            Button("キャンセル", role: .cancel) {
                pendingChannelRemoval = nil
            }
        } message: {
            Text("このチャンネルの動画キャッシュと不要サムネイルも整理します。")
        }
        .alert(item: $removalFeedback) { feedback in
            Alert(
                title: Text(feedback.title),
                message: Text(feedback.detail),
                dismissButton: .default(Text("OK")) {
                    if !path.isEmpty {
                        path.removeLast()
                    }
                }
            )
        }
        .onAppear {
            if context.prefersAutomaticRefresh {
                isAutomaticRefreshInProgress = true
            }
            StartupDiagnostics.shared.mark("channelVideosShown")
        }
    }

    private var channelTitle: String {
        coordinator.maintenanceItems.first(where: { $0.channelID == context.channelID })?.channelTitle
            ?? videos.first(where: { !$0.channelTitle.isEmpty })?.channelTitle
            ?? context.preferredChannelTitle
            ?? context.channelID
    }

    private func reloadVideos() async {
        if context.prefersAutomaticRefresh {
            let clock = ContinuousClock()
            let start = clock.now
            isAutomaticRefreshInProgress = true

            videos = await coordinator.openChannelVideos(context)

            let minimumDuration = AppLaunchMode.current.usesMockData
                ? Self.automaticRefreshIndicatorMockDuration
                : Self.automaticRefreshIndicatorMinimumDuration
            let elapsed = start.duration(to: clock.now)
            if elapsed < minimumDuration {
                try? await Task.sleep(for: minimumDuration - elapsed)
            }
            isAutomaticRefreshInProgress = false
        } else {
            videos = await coordinator.loadVideosForChannel(context.channelID)
        }
        RuntimeDiagnostics.shared.record(
            "channel_videos_loaded",
            detail: "チャンネル動画一覧を読み込み",
            metadata: [
                "channelID": context.channelID,
                "videoCount": String(videos.count),
                "title": channelTitle
            ]
        )
    }
}
