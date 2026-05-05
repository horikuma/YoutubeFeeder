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
            await viewModel.refreshSelectedChannel()
        }
    }

    private func setDisplayMode(_ mode: ChannelBrowseDisplayMode) {
        viewModel.setDisplayMode(mode)
    }
}

