import SwiftUI

struct ChannelBrowseDetailView: View {
    let selectedTitle: String
    let layout: AppLayout
    let openVideo: (CachedVideo) -> Void
    let viewModel: ChannelBrowseViewModel
    @Binding var state: ChannelBrowseLogic

    private var selectedChannelID: String? {
        state.selectedChannelID
    }

    private var displayMode: ChannelBrowseDisplayMode {
        guard let selectedChannelID else { return .videos }
        return state.displayMode(for: selectedChannelID)
    }

    private var selectedPlaylist: PlaylistBrowseItem? {
        guard let selectedChannelID else { return nil }
        return state.selectedPlaylist(for: selectedChannelID)
    }

    private var selectedPlaylistID: String? {
        guard let selectedChannelID else { return nil }
        return state.selectedPlaylistID(for: selectedChannelID)
    }

    private var selectedPlaylistPage: PlaylistBrowseVideosPage? {
        selectedPlaylistID.flatMap { state.playlistVideosPage(for: $0) }
    }

    private var selectedPlaylistVideos: [PlaylistBrowseVideo] {
        guard let selectedChannelID else { return [] }
        return state.selectedPlaylistVideos(for: selectedChannelID)
    }

    private var detailSubtitle: String {
        guard selectedChannelID != nil else { return "左側のチャンネルを選ぶと詳細が表示されます" }
        switch displayMode {
        case .videos:
            return "このチャンネルの動画を新しい順に表示"
        case .playlists:
            if let selectedPlaylist {
                return "\(selectedPlaylist.title) の動画を表示"
            }
            return "このチャンネルのプレイリストを表示"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(selectedTitle)
                    .font(.system(size: 34, weight: .black, design: .rounded))

                Text(detailSubtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if selectedChannelID != nil {
                    ChannelBrowseDisplayModeToggleView(
                        displayMode: displayMode,
                        setDisplayMode: setDisplayMode(_:))

                    switch displayMode {
                    case .videos:
                    ChannelBrowseVideosContentView(
                        layout: layout,
                        openVideo: openVideo,
                        viewModel: viewModel,
                        state: $state,
                        selectedChannelID: selectedChannelID
                    )
                    case .playlists:
                        ChannelBrowsePlaylistsContentView(
                            layout: layout,
                            openVideo: openVideo,
                            state: $state,
                            viewModel: viewModel,
                            selectedPlaylist: selectedPlaylist,
                            selectedPlaylistPage: selectedPlaylistPage,
                            selectedPlaylistVideos: selectedPlaylistVideos
                        )
                    }
                } else {
                    ChannelBrowseEmptyStateView(
                        title: "動画一覧",
                        value: "チャンネル未選択",
                        detail: "左側のチャンネルを選ぶと動画を表示します"
                    )
                }
            }
            .frame(maxWidth: layout.readableContentWidth ?? layout.contentWidth ?? .infinity, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await refreshSelectedChannel(viewModel: viewModel)
        }
    }

    private func setDisplayMode(_ mode: ChannelBrowseDisplayMode) {
        viewModel.setDisplayMode(mode)
    }
}

@MainActor
private func refreshSelectedChannel(viewModel: ChannelBrowseViewModel) async {
    guard let selectedChannelID = viewModel.state.selectedChannelID else { return }
    switch viewModel.state.displayMode(for: selectedChannelID) {
    case .videos:
        RuntimeDiagnostics.shared.record(
            "channel_refresh_gesture",
            detail: "スプリット表示の動画一覧で下スワイプ更新",
            metadata: [
                "channelID": selectedChannelID,
                "screen": "splitChannelVideos"
            ]
        )
        if case let .channelVideos(refreshedVideos) = await viewModel.coordinator.refresh(
            intent: .channelVideos(channelID: selectedChannelID)
        ) {
            withAnimation(.easeOut(duration: 0.25)) {
                viewModel.state.refreshSelectedChannelVideos(refreshedVideos)
            }
        }
        viewModel.nextPageToken = nil
        viewModel.hasStartedPaging = false
        viewModel.didRequestLoadMore = false
        RuntimeDiagnostics.shared.record(
            "channel_refresh_view_reload_finished",
            detail: "スプリット表示の動画一覧リロード完了",
            metadata: [
                "channelID": selectedChannelID,
                "videoCount": String(viewModel.state.videosForSelectedChannel().count)
            ]
        )
    case .playlists:
        let snapshot = await viewModel.coordinator.loadSnapshot()
        let playlists = snapshot.playlists
        viewModel.playlistSnapshot = playlists
        withAnimation(.easeOut(duration: 0.25)) {
            if let playlistsForChannel = playlists.playlistsByChannelID[selectedChannelID] {
                viewModel.state.refreshPlaylists(playlistsForChannel, for: selectedChannelID)
            }
            if let selectedPlaylistID = viewModel.state.selectedPlaylistID(for: selectedChannelID),
               let page = playlists.playlistPagesByPlaylistID[selectedPlaylistID] {
                viewModel.state.refreshPlaylistVideos(page)
            }
        }
    }
}
