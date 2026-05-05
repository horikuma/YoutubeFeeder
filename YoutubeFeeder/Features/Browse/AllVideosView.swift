import SwiftUI

struct AllVideosView: View {
    let coordinator: FeedCacheCoordinator
    let openVideo: (CachedVideo) -> Void
    @Binding var path: NavigationPath
    let layout: AppLayout
    @State private var videoState = VideoListLogic()

    var body: some View {
        InteractiveListView(
            title: "動画一覧",
            subtitle: "キャッシュ済み動画を新しい順に表示",
            coordinator: coordinator,
            path: $path,
            layout: layout,
            onRefresh: nil,
            allowsRefreshCommandBinding: true
        ) {
            if videoState.videos.isEmpty {
                ChannelBrowseEmptyStateView(
                    title: "動画一覧",
                    value: "まだありません",
                    detail: "収集が進むとここに長尺動画を表示します"
                )
            } else {
                LazyVGrid(columns: layout.listColumns, spacing: layout.isPad ? 20 : 14) {
                    ForEach(Array(videoState.videos.enumerated()), id: \.element.id) { offset, video in
                        VideoTile(
                            video: video,
                            tapAction: {
                                openVideo(video)
                            },
                            openVideoAction: nil,
                            primaryMenuAction: {
                                path.append(
                                    MaintenanceRoute.channelVideos(
                                        ChannelVideosRouteContext(
                                            channelID: video.channelID,
                                            preferredChannelTitle: video.channelTitle.isEmpty ? nil : video.channelTitle,
                                            selectedVideoID: video.id
                                        )
                                    )
                                )
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
            coordinator.loadVideosFromCache()
        }
        .onReceive(coordinator.$videos) { videos in
            withAnimation(.easeOut(duration: 0.25)) {
                videoState.setVideos(videos)
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
                    if case let .channelRemoval(feedback) = await coordinator.refresh(
                        intent: .removeChannel(channelID: pendingChannelRemoval.channelID)
                    ) {
                        await MainActor.run {
                            videoState.applyRemovalFeedback(feedback)
                            coordinator.loadVideosFromCache()
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
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            StartupDiagnostics.shared.mark("allVideosShown")
        }
    }
}
