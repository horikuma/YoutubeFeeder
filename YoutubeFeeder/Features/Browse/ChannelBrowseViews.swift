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

    @State private var items: [ChannelBrowseItem] = []
    @State private var pendingChannelRemoval: PendingChannelRemoval?
    @State private var removalFeedback: ChannelRemovalFeedback?

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
                    items: items,
                    onRequestRemoval: requestRemoval,
                    onRefresh: refreshChannelBrowseItems
                )
            case .compact:
                ChannelBrowseCompactView(
                    coordinator: coordinator,
                    layout: layout,
                    path: $path,
                    sortDescriptor: sortDescriptor,
                    items: items,
                    tipsSummary: tipsSummary,
                    onRequestRemoval: requestRemoval,
                    onRefresh: refreshChannelBrowseItems
                )
            }
        }
        .task {
            await loadChannelBrowseItems()
        }
        .onReceive(coordinator.$maintenanceItems.dropFirst()) { _ in
            RuntimeDiagnostics.shared.record(
                "channel_list_received_update",
                detail: "チャンネル一覧が maintenanceItems の更新を受信",
                metadata: [
                    "itemCount": String(coordinator.maintenanceItems.count),
                    "sort": sortDescriptor.shortLabel
                ]
            )
            Task {
                await loadChannelBrowseItems()
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
                            handleRemovalFeedback(feedback)
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
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            StartupDiagnostics.shared.mark("channelListShown")
        }
    }

    private func requestRemoval(_ item: ChannelBrowseItem) {
        pendingChannelRemoval = PendingChannelRemoval(channelID: item.channelID, channelTitle: item.channelTitle)
    }

    private func handleRemovalFeedback(_ feedback: ChannelRemovalFeedback) {
        removalFeedback = feedback
        Task {
            await loadChannelBrowseItems()
        }
    }

    private var tipsSummary: ChannelBrowseTipsSummary {
        ChannelBrowseTipsSummary.build(items: items, sortDescriptor: sortDescriptor)
    }

    private func loadChannelBrowseItems() async {
        items = await coordinator.loadChannelBrowseItems(sortDescriptor: sortDescriptor)
    }

    private func refreshChannelBrowseItems() async {
        _ = await coordinator.performRefreshAction(.home)
        await loadChannelBrowseItems()
    }
}

private struct ChannelBrowseCompactView: View {
    let coordinator: FeedCacheCoordinator
    let layout: AppLayout
    @Binding var path: NavigationPath
    let sortDescriptor: ChannelBrowseSortDescriptor
    let items: [ChannelBrowseItem]
    let tipsSummary: ChannelBrowseTipsSummary
    let onRequestRemoval: (ChannelBrowseItem) -> Void
    let onRefresh: () async -> Void

    private var usesDesktopMenus: Bool {
        AppInteractionPlatform.current.usesPrimaryClickForMenus
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
                                    onRequestRemoval(item)
                                }
                            }
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
                    onRequestRemoval(item)
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
    let items: [ChannelBrowseItem]
    let onRequestRemoval: (ChannelBrowseItem) -> Void
    let onRefresh: () async -> Void

    @State private var selectedChannelID: String?
    @State private var videosByChannelID: [String: [CachedVideo]] = [:]
    @State private var loadingChannelIDs: Set<String> = []

    private var usesDesktopMenus: Bool {
        AppInteractionPlatform.current.usesPrimaryClickForMenus
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
                                    onRequestRemoval: onRequestRemoval
                                )
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
            sidebarHeader
        }
    }

    private var rightPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(selectedTitle)
                    .font(.system(size: 34, weight: .black, design: .rounded))

                Text("このチャンネルの動画を新しい順に表示")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if selectedChannelID != nil {
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
                                        onRequestRemoval(
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
                            }
                        }
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

    private var videosForSelectedChannel: [CachedVideo] {
        guard let selectedChannelID else { return [] }
        return videosByChannelID[selectedChannelID] ?? []
    }

    private var selectedTitle: String {
        guard let selectedChannelID else { return "チャンネル未選択" }
        return items.first(where: { $0.channelID == selectedChannelID })?.channelTitle ?? selectedChannelID
    }

    private func selectChannel(_ channelID: String) {
        selectedChannelID = channelID
        loadVideosIfNeeded(for: channelID)
    }

    private func applyDefaultSelectionIfNeeded() {
        if let selectedChannelID, items.contains(where: { $0.channelID == selectedChannelID }) {
            loadVideosIfNeeded(for: selectedChannelID)
            return
        }
        guard let firstChannelID = items.first?.channelID else { return }
        self.selectedChannelID = firstChannelID
        loadVideosIfNeeded(for: firstChannelID)
    }

    private func loadVideosIfNeeded(for channelID: String) {
        guard videosByChannelID[channelID] == nil else { return }
        guard !loadingChannelIDs.contains(channelID) else { return }
        loadingChannelIDs.insert(channelID)
        Task {
            let loadedVideos = await coordinator.loadVideosForChannel(channelID)
            await MainActor.run {
                loadingChannelIDs.remove(channelID)
                if videosByChannelID[channelID] == nil {
                    videosByChannelID[channelID] = loadedVideos
                }
            }
        }
    }

    private func refreshSelectedChannel() async {
        guard let selectedChannelID else { return }
        RuntimeDiagnostics.shared.record(
            "channel_refresh_gesture",
            detail: "スプリット表示の動画一覧で下スワイプ更新",
            metadata: [
                "channelID": selectedChannelID,
                "screen": "splitChannelVideos"
            ]
        )
        await coordinator.refreshChannelManually(selectedChannelID)
        videosByChannelID[selectedChannelID] = await coordinator.loadVideosForChannel(selectedChannelID)
        RuntimeDiagnostics.shared.record(
            "channel_refresh_view_reload_finished",
            detail: "スプリット表示の動画一覧リロード完了",
            metadata: [
                "channelID": selectedChannelID,
                "videoCount": String(videosByChannelID[selectedChannelID]?.count ?? 0)
            ]
        )
    }

    private var tipsSummary: ChannelBrowseTipsSummary {
        ChannelBrowseTipsSummary.build(items: items, sortDescriptor: sortDescriptor)
    }

    private func selectionMenu(for item: ChannelBrowseItem) -> TileMenuConfiguration {
        TileMenuConfiguration(
            primaryAction: usesDesktopMenus ? TileMenuAction(title: "このチャンネルを表示", role: nil) {
                selectChannel(item.channelID)
            } : nil,
            secondaryActions: [
                TileMenuAction(title: "チャンネルを削除", role: .destructive) {
                    onRequestRemoval(item)
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

struct AllVideosView: View {
    let coordinator: FeedCacheCoordinator
    let openVideo: (CachedVideo) -> Void
    @Binding var path: NavigationPath
    let layout: AppLayout
    @State private var pendingChannelRemoval: PendingChannelRemoval?
    @State private var removalFeedback: ChannelRemovalFeedback?

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
            if coordinator.videos.isEmpty {
                MetricTile(title: "動画一覧", value: "まだありません", detail: "収集が進むとここに長尺動画を表示します")
            } else {
                LazyVGrid(columns: layout.listColumns, spacing: layout.isPad ? 20 : 14) {
                    ForEach(Array(coordinator.videos.enumerated()), id: \.element.id) { offset, video in
                        VideoTile(
                            video: video,
                            tapAction: {
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
                            openVideoAction: nil,
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
            coordinator.loadVideosFromCache()
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
                            coordinator.loadVideosFromCache()
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
