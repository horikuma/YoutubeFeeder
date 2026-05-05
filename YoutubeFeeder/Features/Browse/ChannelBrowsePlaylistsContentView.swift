import SwiftUI

struct ChannelBrowsePlaylistsContentView: View {
    let layout: AppLayout
    let openVideo: (CachedVideo) -> Void
    @Binding var state: ChannelBrowseLogic
    let viewModel: ChannelBrowseViewModel
    let selectedPlaylist: PlaylistBrowseItem?
    let selectedPlaylistPage: PlaylistBrowseVideosPage?
    let selectedPlaylistVideos: [PlaylistBrowseVideo]
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let selectedPlaylist {
                ChannelBrowsePlaylistBackView(
                    title: selectedPlaylist.title,
                    onBack: clearSelectedPlaylist
                )

                ChannelBrowsePlaylistSortControlView(
                    binding: playlistVideoSortOrderBinding(for: selectedPlaylist.playlistID)
                )

                playlistVideosContent
            } else {
                playlistListContent
            }
        }
    }

    private var playlistListContent: some View {
        Group {
            if playlistsForSelectedChannel.isEmpty {
                ChannelBrowseEmptyStateView(
                    title: "プレイリスト一覧",
                    value: "まだありません",
                    detail: "このチャンネルのプレイリストがあるとここに表示します"
                )
            } else {
                LazyVGrid(columns: layout.listColumns, spacing: 20) {
                    ForEach(Array(playlistsForSelectedChannel.enumerated()), id: \.element.id) { offset, playlist in
                        Button {
                            selectPlaylist(playlist.playlistID)
                        } label: {
                            PlaylistBrowseTile(
                                item: playlist,
                                previewVideo: playlistPreviewVideo(for: playlist),
                                index: offset + 1,
                                isSelected: selectedPlaylist?.playlistID == playlist.playlistID
                            )
                        }
                        .buttonStyle(.plain)
                        .tileActionMenu(
                            menu: playlistMenu(for: playlist),
                            accessibilityIdentifier: "playlist.tile.\(playlist.playlistID)",
                            desktopTriggerStyle: .contextMenu
                        )
                        .listInsertionTransition()
                    }
                }
            }
        }
    }

    private var playlistVideosContent: some View {
        Group {
            if let selectedPlaylistPage = selectedPlaylistPage {
                if selectedPlaylistPage.videos.isEmpty {
                    ChannelBrowseLoadingView(
                        title: "プレイリスト内動画",
                        value: "まだありません",
                        detail: "このプレイリストの動画があるとここに表示します"
                    )
                } else {
                    LazyVGrid(columns: layout.listColumns, spacing: 20) {
                        ForEach(Array(selectedPlaylistVideos.enumerated()), id: \.element.id) { offset, video in
                            let cachedVideo = playlistCachedVideo(for: video)
                            VideoTile(
                                video: cachedVideo,
                                tapAction: nil,
                                openVideoAction: {
                                    openVideo(cachedVideo)
                                },
                                removeChannel: nil,
                                index: offset + 1,
                                desktopPrimaryClickAction: {
                                    openVideo(cachedVideo)
                                },
                                desktopMenuTriggerStyle: .contextMenu,
                                includesOpenVideoInMenu: true
                            )
                            .listInsertionTransition()
                        }
                    }
                }
            } else {
                ChannelBrowseLoadingView(
                    title: "プレイリスト内動画",
                    value: "読み込み中",
                    detail: "プレイリストを準備しています"
                )
            }
        }
    }

    private var playlistsForSelectedChannel: [PlaylistBrowseItem] {
        guard let channelID = state.selectedChannelID else { return [] }
        return state.playlists(for: channelID)
    }

    private func selectPlaylist(_ playlistID: String) {
        viewModel.selectPlaylist(playlistID)
    }

    private func clearSelectedPlaylist() {
        viewModel.clearSelectedPlaylist()
    }

    private func playlistVideoSortOrderBinding(for playlistID: String) -> Binding<PlaylistBrowseVideoSortOrder> {
        Binding(
            get: {
                state.playlistVideoSortOrder(for: playlistID)
            },
            set: { newValue in
                var logic = state
                logic.setPlaylistVideoSortOrder(newValue, for: playlistID)
                state = logic
            }
        )
    }

    private func playlistMenu(for item: PlaylistBrowseItem) -> TileMenuConfiguration {
        TileMenuConfiguration(
            primaryAction: nil,
            secondaryActions: [
                TileMenuAction(title: "連続再生", role: nil) {
                    openPlaylistContinuousPlay(item)
                }
            ]
        )
    }

    private func openPlaylistContinuousPlay(_ item: PlaylistBrowseItem) {
        guard let url = viewModel.playlistContinuousPlayURL(for: item) else { return }
        openURL(url)
    }

    private func playlistPreviewVideo(for item: PlaylistBrowseItem) -> CachedVideo {
        viewModel.playlistPreviewVideo(for: item)
    }

    private func playlistCachedVideo(for video: PlaylistBrowseVideo) -> CachedVideo {
        viewModel.playlistCachedVideo(for: video)
    }

}

