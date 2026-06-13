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
                                previewVideo: makePlaylistPreviewVideo(
                                    for: playlist,
                                    snapshot: viewModel.playlistsSnapshot
                                ),
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
                            let cachedVideo = makePlaylistCachedVideo(for: video)
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
        guard let channelID = state.selectedChannelID else { return }
        AppConsoleLogger.appLifecycle.info(
            "playlist_selection_view_start",
            metadata: [
                "channelID": channelID,
                "playlistID": playlistID
            ]
        )
        var logic = state
        logic.selectPlaylist(playlistID, for: channelID)
        state = logic
        viewModel.loadPlaylistVideosIfNeeded(for: playlistID)
    }

    private func clearSelectedPlaylist() {
        guard let channelID = state.selectedChannelID else { return }
        AppConsoleLogger.appLifecycle.info(
            "playlist_selection_view_clear",
            metadata: [
                "channelID": channelID
            ]
        )
        var logic = state
        logic.selectPlaylist(nil, for: channelID)
        state = logic
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
        guard let url = makePlaylistContinuousPlayURL(
            for: item,
            snapshot: viewModel.playlistsSnapshot
        ) else { return }
        openURL(url)
    }
}

private func makePlaylistPreviewVideo(
    for item: PlaylistBrowseItem,
    snapshot: FeedCachePlaylistSnapshot
) -> CachedVideo {
    CachedVideo(
        id: item.firstVideoID ?? item.playlistID,
        channelID: item.channelID,
        channelTitle: item.channelTitle,
        channelDisplayTitle: item.channelTitle,
        title: item.title,
        publishedAt: item.publishedAt,
        videoURL: snapshot.playlistContinuousPlayURLsByPlaylistID[item.playlistID]
            ?? URL(string: "https://www.youtube.com/playlist?list=\(item.playlistID)"),
        thumbnailRemoteURL: item.firstVideoThumbnailURL ?? item.thumbnailURL,
        thumbnailLocalFilename: nil,
        fetchedAt: .now,
        searchableText: [item.title, item.channelTitle, item.playlistID].joined(separator: "\n").lowercased(),
        durationSeconds: nil,
        viewCount: item.itemCount,
        metadataBadgeText: item.itemCount.map { "\($0)本" }
    )
}

private func makePlaylistCachedVideo(for video: PlaylistBrowseVideo) -> CachedVideo {
    CachedVideo(
        id: video.id,
        channelID: video.channelID,
        channelTitle: video.channelTitle,
        channelDisplayTitle: video.channelTitle,
        title: video.title,
        publishedAt: video.publishedAt,
        videoURL: video.videoURL,
        thumbnailRemoteURL: video.thumbnailURL,
        thumbnailLocalFilename: nil,
        fetchedAt: .now,
        searchableText: [video.title, video.channelTitle, video.id].joined(separator: "\n").lowercased(),
        durationSeconds: video.durationSeconds,
        viewCount: video.viewCount
    )
}

private func makePlaylistContinuousPlayURL(
    for item: PlaylistBrowseItem,
    snapshot: FeedCachePlaylistSnapshot
) -> URL? {
    snapshot.playlistContinuousPlayURLsByPlaylistID[item.playlistID]
        ?? URL(string: "https://www.youtube.com/playlist?list=\(item.playlistID)")
}
