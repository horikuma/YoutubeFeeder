import SwiftUI
import Combine

struct PendingChannelRemoval: Identifiable, Hashable {
    let channelID: String
    let channelTitle: String

    var id: String { channelID }
}

struct ChannelBrowseView: View {
    let coordinator: FeedCacheCoordinator
    let openVideo: (CachedVideo) -> Void
    @Binding var path: NavigationPath
    let layout: AppLayout
    let sortDescriptor: ChannelBrowseSortDescriptor
    let presentation: BasicGUIBrowsePresentation

    @StateObject private var viewModel: ChannelBrowseViewModel

    init(
        coordinator: FeedCacheCoordinator,
        openVideo: @escaping (CachedVideo) -> Void,
        path: Binding<NavigationPath>,
        layout: AppLayout,
        sortDescriptor: ChannelBrowseSortDescriptor,
        presentation: BasicGUIBrowsePresentation
    ) {
        self.coordinator = coordinator
        self.openVideo = openVideo
        _path = path
        self.layout = layout
        self.sortDescriptor = sortDescriptor
        self.presentation = presentation
        _viewModel = StateObject(
            wrappedValue: ChannelBrowseViewModel(
                coordinator: coordinator,
                sortDescriptor: sortDescriptor
            )
        )
    }

    var body: some View {
        Group {
            switch presentation {
            case .split:
                ChannelBrowseRegularView(
                    coordinator: coordinator,
                    openVideo: openVideo,
                    path: $path,
                    layout: layout,
                    sortDescriptor: sortDescriptor,
                    viewModel: viewModel,
                    state: $viewModel.state,
                    onRefresh: {
                        await viewModel.refreshChannelBrowseItems()
                    }
                )
            case .compact:
                ChannelBrowseCompactView(
                    coordinator: coordinator,
                    layout: layout,
                    path: $path,
                    sortDescriptor: sortDescriptor,
                    state: $viewModel.state,
                    onRefresh: {
                        await viewModel.refreshChannelBrowseItems()
                    }
                )
            }
        }
        .task {
            await viewModel.loadChannelBrowseItems()
        }
        .onReceive(coordinator.$maintenanceItems.dropFirst()) { _ in
            viewModel.maintenanceItemsDidChange()
        }
        .confirmationDialog(
            viewModel.state.pendingChannelRemoval.map { "\($0.channelTitle)を削除しますか" } ?? "",
            isPresented: Binding(
                get: { viewModel.state.pendingChannelRemoval != nil },
                set: { if !$0 { viewModel.clearPendingRemoval() } }
            ),
            titleVisibility: .visible
        ) {
            Button("チャンネルを削除", role: .destructive) {
                Task {
                    await viewModel.confirmPendingRemoval()
                }
            }
            Button("キャンセル", role: .cancel) {
                viewModel.clearPendingRemoval()
            }
        } message: {
            Text("このチャンネルの動画キャッシュと不要サムネイルも整理します。")
        }
        .alert(item: $viewModel.state.removalFeedback) { feedback in
            Alert(
                title: Text(feedback.title),
                message: Text(feedback.detail),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            viewModel.onAppear()
        }
    }
}

private struct ChannelBrowseCompactView: View {
    let coordinator: FeedCacheCoordinator
    let layout: AppLayout
    @Binding var path: NavigationPath
    let sortDescriptor: ChannelBrowseSortDescriptor
    @Binding var state: ChannelBrowseLogic
    let onRefresh: () async -> Void

    private var usesDesktopMenus: Bool {
        AppInteractionPlatform.current.usesPrimaryClickForMenus
    }

    private var items: [ChannelBrowseItem] {
        state.items
    }

    private var tipsSummary: ChannelBrowseTipsSummary {
        ChannelBrowseTipsSummary.build(items: state.items, sortDescriptor: sortDescriptor)
    }

    var body: some View {
        InteractiveListView(
            title: "チャンネル一覧",
            subtitle: sortDescriptor.listSubtitle,
            coordinator: coordinator,
            path: $path,
            layout: layout,
            onRefresh: onRefresh,
            allowsRefreshCommandBinding: true
        ) {
            ChannelBrowseTipsTile(summary: tipsSummary)

            if items.isEmpty {
                MetricTile(title: "チャンネル一覧", value: "まだありません", detail: "キャッシュが増えるとここに並びます")
            } else {
                LazyVGrid(columns: layout.listColumns, spacing: layout.isPad ? 20 : 14) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { offset, item in
                        if usesDesktopMenus {
                            Button {
                                path.append(
                                    MaintenanceRoute.channelVideos(
                                        ChannelVideosRouteContext(
                                            channelID: item.channelID,
                                            preferredChannelTitle: item.channelTitle
                                        )
                                    )
                                )
                            } label: {
                                ChannelNavigationTile(item: item, index: offset + 1)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("channel.tile.\(item.channelID)")
                            .contextMenu {
                                Button("チャンネルを削除", role: .destructive) {
                                    state.requestRemoval(for: item)
                                }
                            }
                            .listInsertionTransition()
                        } else {
                            NavigationLink(
                                value: MaintenanceRoute.channelVideos(
                                    ChannelVideosRouteContext(
                                        channelID: item.channelID,
                                        preferredChannelTitle: item.channelTitle
                                    )
                                )
                            ) {
                                ChannelNavigationTile(item: item, index: offset + 1)
                                    .accessibilityIdentifier("channel.tile.\(item.channelID)")
                            }
                            .buttonStyle(.plain)
                            .tileActionMenu(menu: channelMenu(for: item))
                            .listInsertionTransition()
                        }
                    }
                }
            }
        }
    }

    private func channelMenu(for item: ChannelBrowseItem) -> TileMenuConfiguration {
        TileMenuConfiguration(
            primaryAction: usesDesktopMenus ? TileMenuAction(title: "動画一覧を開く", role: nil) {
                path.append(
                    MaintenanceRoute.channelVideos(
                        ChannelVideosRouteContext(
                            channelID: item.channelID,
                            preferredChannelTitle: item.channelTitle
                        )
                    )
                )
            } : nil,
            secondaryActions: [
                TileMenuAction(title: "チャンネルを削除", role: .destructive) {
                    state.requestRemoval(for: item)
                }
            ]
        )
    }
}

private struct ChannelBrowseRegularView: View {
    let coordinator: FeedCacheCoordinator
    let openVideo: (CachedVideo) -> Void
    @Binding var path: NavigationPath
    let layout: AppLayout
    let sortDescriptor: ChannelBrowseSortDescriptor
    let viewModel: ChannelBrowseViewModel
    @Binding var state: ChannelBrowseLogic
    let onRefresh: () async -> Void
    @Environment(\.openURL) private var openURL
    @State private var didRequestLoadMore = false
    @State private var nextPageToken: String?
    @State private var hasStartedPaging = false

    private var usesDesktopMenus: Bool {
        AppInteractionPlatform.current.usesPrimaryClickForMenus
    }

    private var items: [ChannelBrowseItem] {
        state.items
    }

    private var selectedChannelID: String? {
        state.selectedChannelID
    }

    private var videosForSelectedChannel: [CachedVideo] {
        state.videosForSelectedChannel()
    }

    private var displayMode: ChannelBrowseDisplayMode {
        guard let selectedChannelID else { return .videos }
        return state.displayMode(for: selectedChannelID)
    }

    private var playlistsForSelectedChannel: [PlaylistBrowseItem] {
        guard let selectedChannelID else { return [] }
        return state.playlists(for: selectedChannelID)
    }

    private var selectedPlaylistID: String? {
        guard let selectedChannelID else { return nil }
        return state.selectedPlaylistID(for: selectedChannelID)
    }

    private var selectedPlaylist: PlaylistBrowseItem? {
        guard let selectedChannelID else { return nil }
        return state.selectedPlaylist(for: selectedChannelID)
    }

    private var selectedPlaylistVideos: [PlaylistBrowseVideo] {
        guard let selectedChannelID else { return [] }
        return state.selectedPlaylistVideos(for: selectedChannelID)
    }

    private var selectedPlaylistPage: PlaylistBrowseVideosPage? {
        selectedPlaylistID.flatMap { state.playlistVideosPage(for: $0) }
    }

    private var selectedTitle: String {
        state.selectedTitle()
    }

    var body: some View {
        NavigationSplitView {
            leftPane
                .navigationTitle("チャンネル一覧")
        } detail: {
            rightPane
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

    private var leftPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ChannelBrowseTipsTile(summary: tipsSummary)

                if items.isEmpty {
                    MetricTile(title: "チャンネル一覧", value: "まだありません", detail: "キャッシュが増えるとここに並びます")
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { offset, item in
                            ChannelSelectionTile(
                                item: item,
                                isSelected: item.channelID == selectedChannelID,
                                index: offset + 1
                            )
                            .onTapGesture {
                                selectChannel(item.channelID)
                            }
                            .modifier(
                                ChannelSelectionActionModifier(
                                    item: item,
                                    usesDesktopMenus: usesDesktopMenus,
                                    menu: selectionMenu(for: item),
                                    onRequestRemoval: { _ in state.requestRemoval(for: item) }
                                )
                            )
                            .listInsertionTransition()
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
            sidebarHeader
        }
    }

    private var rightPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(selectedTitle)
                    .font(.system(size: 34, weight: .black, design: .rounded))

                Text(detailSubtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if selectedChannelID != nil {
                    displayModeToggle

                    switch displayMode {
                    case .videos:
                        videosContent
                    case .playlists:
                        playlistsContent
                    }
                } else {
                    MetricTile(title: "動画一覧", value: "チャンネル未選択", detail: "左側のチャンネルを選ぶと動画を表示します")
                }
            }
            .frame(maxWidth: layout.readableContentWidth ?? layout.contentWidth ?? .infinity, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await refreshSelectedChannel()
        }
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

    private var displayModeToggle: some View {
        HStack(spacing: 8) {
            displayModeButton(title: "動画一覧", mode: .videos)
            displayModeButton(title: "プレイリスト一覧", mode: .playlists)
        }
    }

    private func displayModeButton(title: String, mode: ChannelBrowseDisplayMode) -> some View {
        let isSelected = displayMode == mode
        return Button {
            setDisplayMode(mode)
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? .white : .primary)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                )
        }
        .buttonStyle(.plain)
    }

    private var videosContent: some View {
        Group {
            if AppLaunchMode.current.usesMockData {
                UITestMarker(
                    identifier: "screen.channelVideos.loaded",
                    value: videosForSelectedChannel.first?.id ?? "none"
                )
            }

            if videosForSelectedChannel.isEmpty {
                MetricTile(title: "動画一覧", value: "まだありません", detail: "このチャンネルのキャッシュがあるとここに表示します")
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
                            requestLoadMoreIfNeeded(for: selectedChannelID)
                        }
                        .listInsertionTransition()
                    }
                }
            }
        }
    }

    private var playlistsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let selectedPlaylist {
                HStack(spacing: 12) {
                    Button("プレイリスト一覧へ戻る") {
                        clearSelectedPlaylist()
                    }
                    .buttonStyle(.bordered)

                    Text(selectedPlaylist.title)
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .accessibilityIdentifier("channel.playlist.back")

                playlistVideosContent
            } else {
                playlistListContent
            }
        }
    }

    private var playlistListContent: some View {
        Group {
            if playlistsForSelectedChannel.isEmpty {
                MetricTile(title: "プレイリスト一覧", value: "まだありません", detail: "このチャンネルのプレイリストがあるとここに表示します")
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
                                isSelected: selectedPlaylistID == playlist.playlistID
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
                    MetricTile(title: "プレイリスト内動画", value: "まだありません", detail: "このプレイリストの動画があるとここに表示します")
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
                MetricTile(title: "プレイリスト内動画", value: "読み込み中", detail: "プレイリストを準備しています")
            }
        }
    }

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("チャンネル一覧")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .accessibilityIdentifier("screen.title")

            Text(sortDescriptor.listSubtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, layout.horizontalPadding)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .background(Color(.systemGroupedBackground))
    }

    private func selectChannel(_ channelID: String) {
        viewModel.selectChannel(channelID)
    }

    private func applyDefaultSelectionIfNeeded() {
        viewModel.applyDefaultSelectionIfNeeded()
    }

    private func loadVideosIfNeeded(for channelID: String) {
        viewModel.loadCurrentChannelContentIfNeeded(for: channelID)
    }

    private func refreshSelectedChannel() async {
        await viewModel.refreshSelectedChannel()
    }

    private func loadCurrentChannelContentIfNeeded(for channelID: String, forceReload: Bool = false) {
        viewModel.loadCurrentChannelContentIfNeeded(for: channelID, forceReload: forceReload)
    }

    private func setDisplayMode(_ mode: ChannelBrowseDisplayMode) {
        viewModel.setDisplayMode(mode)
    }

    private func clearSelectedPlaylist() {
        viewModel.clearSelectedPlaylist()
    }

    private func selectPlaylist(_ playlistID: String) {
        viewModel.selectPlaylist(playlistID)
    }

    private func loadPlaylistsIfNeeded(for channelID: String, forceReload: Bool = false) {
        viewModel.loadPlaylistsIfNeeded(for: channelID, forceReload: forceReload)
    }

    private func loadPlaylistVideosIfNeeded(for playlistID: String, forceReload: Bool = false) {
        viewModel.loadPlaylistVideosIfNeeded(for: playlistID, forceReload: forceReload)
    }

    private func playlistPreviewVideo(for item: PlaylistBrowseItem) -> CachedVideo {
        viewModel.playlistPreviewVideo(for: item)
    }

    private func playlistCachedVideo(for video: PlaylistBrowseVideo) -> CachedVideo {
        viewModel.playlistCachedVideo(for: video)
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
        guard let url = coordinator.playlistContinuousPlayURL(playlistID: item.playlistID) else { return }
        openURL(url)
    }

    private func requestLoadMoreIfNeeded(for channelID: String?) {
        viewModel.requestLoadMoreIfNeeded(for: channelID)
    }

    private var tipsSummary: ChannelBrowseTipsSummary {
        viewModel.tipsSummary()
    }

    private func selectionMenu(for item: ChannelBrowseItem) -> TileMenuConfiguration {
        TileMenuConfiguration(
            primaryAction: usesDesktopMenus ? TileMenuAction(title: "このチャンネルを表示", role: nil) {
                viewModel.selectChannel(item.channelID)
            } : nil,
            secondaryActions: [
                TileMenuAction(title: "チャンネルを削除", role: .destructive) {
                    viewModel.requestRemoval(for: item)
                }
            ]
        )
    }
}

private struct ChannelSelectionActionModifier: ViewModifier {
    let item: ChannelBrowseItem
    let usesDesktopMenus: Bool
    let menu: TileMenuConfiguration
    let onRequestRemoval: (ChannelBrowseItem) -> Void

    func body(content: Content) -> some View {
        if usesDesktopMenus {
            content
                .accessibilityIdentifier("channel.tile.\(item.channelID)")
                .contextMenu {
                    Button("チャンネルを削除", role: .destructive) {
                        onRequestRemoval(item)
                    }
                }
        } else {
            content
                .tileActionMenu(
                    menu: menu,
                    accessibilityIdentifier: "channel.tile.\(item.channelID)"
                )
        }
    }
}

private struct PlaylistBrowseTile: View {
    let item: PlaylistBrowseItem
    let previewVideo: CachedVideo
    let index: Int?
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [.indigo, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                ThumbnailView(video: previewVideo, contentMode: .fill)
                    .opacity(0.9)
            }
            .overlay {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.82)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? Color.red.opacity(0.95) : (isHovered ? Color.blue.opacity(0.95) : .clear), lineWidth: (isHovered || isSelected) ? 3 : 0)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(item.channelTitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)

                    Text(item.itemCount.map { "\($0)本" } ?? "件数不明")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(16)
            }
            .overlay(alignment: .topTrailing) {
                if let index {
                    PlaylistTileIndexBadge(index: index)
                        .padding(12)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .onHover {
                isHovered = $0
                AppConsoleLogger.browseTileInteraction.debug(
                    "tile_hover_state_changed",
                    metadata: [
                        "kind": "playlist_browse",
                        "playlistID": item.playlistID,
                        "isHovered": "\($0)"
                    ]
                )
            }
    }
}

private struct PlaylistTileIndexBadge: View {
    let index: Int

    var body: some View {
        Text("\(index + 1)")
            .font(.caption.bold())
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(
                Circle().fill(Color.black.opacity(0.72))
            )
            .overlay(
                Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
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
                MetricTile(title: "動画一覧", value: "まだありません", detail: "収集が進むとここに長尺動画を表示します")
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
                    if let feedback = await coordinator.removeChannel(pendingChannelRemoval.channelID) {
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

private struct ChannelBrowseTipsTile: View {
    let summary: ChannelBrowseTipsSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Tips")
                    .font(.headline)
                Spacer()
                Text(summary.countText)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            Text(summary.sortText)
                .font(.title3.bold())
                .foregroundStyle(.primary)

            Text("\(summary.primaryHint) / \(summary.secondaryHint)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.secondary.opacity(0.12), lineWidth: 1)
        }
        .accessibilityIdentifier("channel.tipsTile")
    }
}
