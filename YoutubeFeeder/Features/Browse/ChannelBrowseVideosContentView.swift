import SwiftUI

struct ChannelBrowseVideosContentView: View {
    let layout: AppLayout
    let openVideo: (CachedVideo) -> Void
    let viewModel: ChannelBrowseViewModel
    @Binding var state: ChannelBrowseLogic
    let selectedChannelID: String?

    private var videosForSelectedChannel: [CachedVideo] {
        state.videosForSelectedChannel()
    }

    var body: some View {
        Group {
            if AppLaunchMode.current.usesMockData {
                UITestMarker(
                    identifier: "screen.channelVideos.loaded",
                    value: videosForSelectedChannel.first?.id ?? "none"
                )
            }

            if videosForSelectedChannel.isEmpty {
                ChannelBrowseEmptyStateView(
                    title: "動画一覧",
                    value: "まだありません",
                    detail: "このチャンネルのキャッシュがあるとここに表示します"
                )
            } else {
                LazyVGrid(columns: layout.listColumns, spacing: 20) {
                    ForEach(Array(videosForSelectedChannel.enumerated()), id: \.element.id) { offset, video in
                        VideoTile(
                            video: video,
                            tapAction: nil,
                            openVideoAction: {
                                openVideo(video)
                            },
                            removeChannel: {
                                state.requestRemoval(for:
                                    ChannelBrowseItem(
                                        id: video.channelID,
                                        channelID: video.channelID,
                                        channelTitle: video.channelTitle.isEmpty ? video.channelID : video.channelTitle,
                                        latestPublishedAt: video.publishedAt,
                                        registeredAt: nil,
                                        latestVideo: video,
                                        cachedVideoCount: 0
                                    ),
                                    source: "channel_browse_video_context_menu"
                                )
                            },
                            index: offset + 1,
                            desktopPrimaryClickAction: {
                                openVideo(video)
                            },
                            desktopMenuTriggerStyle: .contextMenu,
                            includesOpenVideoInMenu: false
                        )
                        .onAppear {
                            guard offset >= videosForSelectedChannel.count - 1 else { return }
                            viewModel.requestLoadMoreIfNeeded(for: selectedChannelID)
                        }
                        .listInsertionTransition()
                    }
                }
            }
        }
    }
}
