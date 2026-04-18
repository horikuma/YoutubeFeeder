import SwiftUI

struct ChannelVideosView: View {
    private static let automaticRefreshIndicatorMinimumDuration: Duration = .milliseconds(400)
    private static let automaticRefreshIndicatorMockDuration: Duration = .seconds(2)

    let context: ChannelVideosRouteContext
    let coordinator: FeedCacheCoordinator
    let openVideo: (CachedVideo) -> Void
    @Binding var path: NavigationPath
    let layout: AppLayout

    @State private var videoState = VideoListLogic()

    var body: some View {
        InteractiveListView(
            title: channelTitle,
            subtitle: "このチャンネルの動画を新しい順に表示",
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
                if case let .channelVideos(reloadedVideos) = await coordinator.performRefreshAction(.channel(context)) {
                    await MainActor.run {
                        withAnimation(.easeOut(duration: 0.25)) {
                            videoState.setVideos(reloadedVideos)
                        }
                    }
                }
                RuntimeDiagnostics.shared.record(
                    "channel_refresh_view_reload_finished",
                    detail: "チャンネル動画一覧リロード完了",
                    metadata: [
                        "channelID": context.channelID,
                        "videoCount": String(videoState.videos.count)
                    ]
                )
            },
            allowsRefreshCommandBinding: true
        ) {
            if AppLaunchMode.current.usesMockData {
                UITestMarker(
                    identifier: "screen.channelVideos.loaded",
                    value: videoState.videos.first?.id ?? "none"
                )
                UITestMarker(
                    identifier: "test.channelRefreshTarget",
                    value: coordinator.lastManualChannelRefreshID ?? "none"
                )
                UITestMarker(
                    identifier: "channel.autoRefreshState",
                    value: videoState.isAutomaticRefreshInProgress ? "loading" : "idle"
                )
            }

            if videoState.videos.isEmpty {
                MetricTile(title: "動画一覧", value: "まだありません", detail: "このチャンネルのキャッシュがあるとここに表示します")
            } else {
                LazyVGrid(columns: layout.listColumns, spacing: layout.isPad ? 20 : 14) {
                    ForEach(Array(videoState.videos.enumerated()), id: \.element.id) { offset, video in
                        VideoTile(
                            video: video,
                            tapAction: nil,
                            openVideoAction: {
                                openVideo(video)
                            },
                            removeChannel: {
                                videoState.requestRemoval(
                                    for: ChannelBrowseItem(
                                        id: video.channelID,
                                        channelID: video.channelID,
                                        channelTitle: video.channelTitle.isEmpty ? video.channelID : video.channelTitle,
                                        latestPublishedAt: video.publishedAt,
                                        registeredAt: nil,
                                        latestVideo: video,
                                        cachedVideoCount: 0
                                    )
                                )
                            },
                            index: offset + 1,
                            desktopPrimaryClickAction: {
                                openVideo(video)
                            },
                            desktopMenuTriggerStyle: .contextMenu
                        )
                        .listInsertionTransition()
                    }
                }
            }
        }
        .task {
            await reloadVideos()
        }
        .overlay(alignment: .top) {
            if videoState.isAutomaticRefreshInProgress {
                VStack(spacing: 0) {
                    ProgressView()
                        .accessibilityIdentifier("channel.autoRefreshIndicator")
                        .padding(.top, 8)
                }
            }
        }
        .confirmationDialog(
            videoState.pendingChannelRemoval.map { "\($0.channelTitle)を削除しますか" } ?? "",
            isPresented: Binding(
                get: { videoState.pendingChannelRemoval != nil },
                set: { if !$0 { videoState.clearPendingRemoval() } }
            ),
            titleVisibility: .visible
        ) {
            Button("チャンネルを削除", role: .destructive) {
                guard let pendingChannelRemoval = videoState.pendingChannelRemoval else { return }
                Task {
                    if let feedback = await coordinator.removeChannel(pendingChannelRemoval.channelID) {
                        await MainActor.run {
                            videoState.applyRemovalFeedback(feedback)
                        }
                    }
                }
                videoState.clearPendingRemoval()
            }
            Button("キャンセル", role: .cancel) {
                videoState.clearPendingRemoval()
            }
        } message: {
            Text("このチャンネルの動画キャッシュと不要サムネイルも整理します。")
        }
        .alert(item: $videoState.removalFeedback) { feedback in
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
                videoState.beginAutomaticRefresh()
            }
            StartupDiagnostics.shared.mark("channelVideosShown")
        }
    }

    private var channelTitle: String {
        coordinator.maintenanceItems.first(where: { $0.channelID == context.channelID })?.channelTitle
            ?? videoState.videos.first(where: { !$0.channelTitle.isEmpty })?.channelTitle
            ?? context.preferredChannelTitle
            ?? context.channelID
    }

    private func reloadVideos() async {
        if context.prefersAutomaticRefresh {
            let clock = ContinuousClock()
            let start = clock.now
            videoState.beginAutomaticRefresh()

            let loadedVideos = await coordinator.openChannelVideos(context)

            let minimumDuration = AppLaunchMode.current.usesMockData
                ? Self.automaticRefreshIndicatorMockDuration
                : Self.automaticRefreshIndicatorMinimumDuration
            let elapsed = start.duration(to: clock.now)
            if elapsed < minimumDuration {
                try? await Task.sleep(for: minimumDuration - elapsed)
            }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) {
                    videoState.finishAutomaticRefresh(loadedVideos)
                }
            }
        } else {
            let loadedVideos = await coordinator.loadVideosForChannel(context.channelID)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) {
                    videoState.setVideos(loadedVideos)
                }
            }
        }
        RuntimeDiagnostics.shared.record(
            "channel_videos_loaded",
            detail: "チャンネル動画一覧を読み込み",
            metadata: [
                "channelID": context.channelID,
                "videoCount": String(videoState.videos.count),
                "title": channelTitle
            ]
        )
    }
}
