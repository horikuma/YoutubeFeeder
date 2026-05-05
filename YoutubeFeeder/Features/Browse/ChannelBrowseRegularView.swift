import SwiftUI

struct ChannelBrowseRegularView: View {
    let coordinator: FeedCacheCoordinator
    let openVideo: (CachedVideo) -> Void
    @Binding var path: NavigationPath
    let layout: AppLayout
    let sortDescriptor: ChannelBrowseSortDescriptor
    let viewModel: ChannelBrowseViewModel
    @Binding var state: ChannelBrowseLogic
    let onRefresh: () async -> Void

    private var items: [ChannelBrowseItem] {
        state.items
    }

    private var selectedChannelID: String? {
        state.selectedChannelID
    }

    private var selectedTitle: String {
        state.selectedTitle()
    }

    private var tipsSummary: ChannelBrowseTipsSummary {
        viewModel.tipsSummary()
    }

    var body: some View {
        NavigationSplitView {
            ChannelBrowseSidebarView(
                items: items,
                selectedChannelID: selectedChannelID,
                layout: layout,
                sortDescriptor: sortDescriptor,
                tipsSummary: tipsSummary,
                usesDesktopMenus: AppInteractionPlatform.current.usesPrimaryClickForMenus,
                onSelectChannel: selectChannel(_:),
                onRequestRemoval: { state.requestRemoval(for: $0) }
            )
            .navigationTitle("チャンネル一覧")
        } detail: {
            ChannelBrowseDetailView(
                selectedTitle: selectedTitle,
                layout: layout,
                openVideo: openVideo,
                viewModel: viewModel,
                state: $state
            )
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(.hidden, for: .navigationBar)
        .modifier(BackSwipePopModifier(path: $path))
        .bindRefreshCommand {
            await onRefresh()
        }
        .onAppear {
            applyDefaultSelectionIfNeeded()
        }
        .onChange(of: items) { _ in
            applyDefaultSelectionIfNeeded()
        }
    }

    private func selectChannel(_ channelID: String) {
        viewModel.selectChannel(channelID)
    }

    private func applyDefaultSelectionIfNeeded() {
        viewModel.applyDefaultSelectionIfNeeded()
    }
}

struct ChannelBrowseSidebarView: View {
    let items: [ChannelBrowseItem]
    let selectedChannelID: String?
    let layout: AppLayout
    let sortDescriptor: ChannelBrowseSortDescriptor
    let tipsSummary: ChannelBrowseTipsSummary
    let usesDesktopMenus: Bool
    let onSelectChannel: (String) -> Void
    let onRequestRemoval: (ChannelBrowseItem) -> Void

    private var sortedItems: [ChannelBrowseItem] {
        items
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ChannelBrowseTipsTile(summary: tipsSummary)

                if sortedItems.isEmpty {
                    ChannelBrowseEmptyStateView(
                        title: "チャンネル一覧",
                        value: "まだありません",
                        detail: "キャッシュが増えるとここに並びます"
                    )
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(sortedItems.enumerated()), id: \.element.id) { offset, item in
                            ChannelBrowseTileView(
                                item: item,
                                index: offset + 1,
                                mode: .selection(
                                    isSelected: item.channelID == selectedChannelID,
                                    onSelect: { onSelectChannel(item.channelID) },
                                    onRequestRemoval: { onRequestRemoval(item) }
                                ),
                                menu: selectionMenu(for: item),
                                usesDesktopMenus: usesDesktopMenus
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: 420, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .top) {
            ChannelBrowseHeaderView(
                title: "チャンネル一覧",
                subtitle: sortDescriptor.listSubtitle,
                layout: layout,
                accessibilityIdentifier: "screen.title"
            )
        }
    }

    private func selectionMenu(for item: ChannelBrowseItem) -> TileMenuConfiguration {
        TileMenuConfiguration(
            primaryAction: usesDesktopMenus ? TileMenuAction(title: "このチャンネルを表示", role: nil) {
                onSelectChannel(item.channelID)
            } : nil,
            secondaryActions: [
                TileMenuAction(title: "チャンネルを削除", role: .destructive) {
                    onRequestRemoval(item)
                }
            ]
        )
    }
}

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
                                    )
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
