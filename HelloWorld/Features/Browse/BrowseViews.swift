import SwiftUI
import Combine

private struct PendingChannelRemoval: Identifiable, Hashable {
    let channelID: String
    let channelTitle: String

    var id: String { channelID }
}

struct ChannelBrowseListView: View {
    let coordinator: FeedCacheCoordinator
    let openVideo: (CachedVideo) -> Void
    @Binding var path: NavigationPath
    let layout: AppLayout
    let sortDescriptor: ChannelBrowseSortDescriptor

    @State private var items: [ChannelBrowseItem] = []
    @State private var pendingChannelRemoval: PendingChannelRemoval?
    @State private var removalFeedback: ChannelRemovalFeedback?

    var body: some View {
        Group {
            if layout.usesSplitChannelBrowser {
                SplitChannelBrowseView(
                    coordinator: coordinator,
                    openVideo: openVideo,
                    path: $path,
                    layout: layout,
                    sortDescriptor: sortDescriptor,
                    items: items,
                    onRequestRemoval: requestRemoval
                )
            } else {
                InteractiveListScreen(
                    title: "チャンネル一覧",
                    subtitle: sortDescriptor.listSubtitle,
                    coordinator: coordinator,
                    path: $path,
                    layout: layout,
                    onRefresh: nil
                ) {
                    if items.isEmpty {
                        MetricTile(title: "チャンネル一覧", value: "まだありません", detail: "キャッシュが増えるとここに並びます")
                    } else {
                        LazyVGrid(columns: layout.listColumns, spacing: layout.isPad ? 20 : 14) {
                            ForEach(items) { item in
                                NavigationLink(value: MaintenanceRoute.channelVideos(item.channelID)) {
                                    ChannelHeroTile(item: item)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        requestRemoval(item)
                                    } label: {
                                        Label("チャンネルを削除", systemImage: "trash")
                                    }
                                }
                                .accessibilityIdentifier("channel.tile.\(item.channelID)")
                            }
                        }
                    }
                }
            }
        }
        .task {
            items = await coordinator.loadChannelBrowseItems(sortDescriptor: sortDescriptor)
        }
        .onReceive(coordinator.$maintenanceItems.dropFirst()) { _ in
            Task {
                items = await coordinator.loadChannelBrowseItems(sortDescriptor: sortDescriptor)
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
            items = await coordinator.loadChannelBrowseItems(sortDescriptor: sortDescriptor)
        }
    }
}

struct SplitChannelBrowseView: View {
    let coordinator: FeedCacheCoordinator
    let openVideo: (CachedVideo) -> Void
    @Binding var path: NavigationPath
    let layout: AppLayout
    let sortDescriptor: ChannelBrowseSortDescriptor
    let items: [ChannelBrowseItem]
    let onRequestRemoval: (ChannelBrowseItem) -> Void

    @State private var selectedChannelID: String?
    @State private var videosByChannelID: [String: [CachedVideo]] = [:]

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
        .onAppear {
            coordinator.suspendLiveUpdates()
            applyDefaultSelectionIfNeeded()
        }
        .onDisappear {
            coordinator.resumeLiveUpdates()
        }
        .onChange(of: items) { _, _ in
            applyDefaultSelectionIfNeeded()
        }
    }

    private var leftPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if items.isEmpty {
                    MetricTile(title: "チャンネル一覧", value: "まだありません", detail: "キャッシュが増えるとここに並びます")
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(items) { item in
                            ChannelSelectionTile(
                                item: item,
                                isSelected: item.channelID == selectedChannelID
                            )
                            .onTapGesture {
                                selectChannel(item.channelID)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    onRequestRemoval(item)
                                } label: {
                                    Label("チャンネルを削除", systemImage: "trash")
                                }
                            }
                            .accessibilityIdentifier("channel.tile.\(item.channelID)")
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

                Text("このチャンネルの動画を新しい順に最大50件表示")
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
                            ForEach(videosForSelectedChannel) { video in
                                LongPressVideoTile(
                                    video: video,
                                    openVideo: {
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
                                    }
                                )
                            }
                        }
                    }
                } else {
                    MetricTile(title: "動画一覧", value: "チャンネル未選択", detail: "左側のチャンネルを選ぶと動画を表示します")
                }
            }
            .frame(maxWidth: layout.contentWidth ?? .infinity, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await refreshSelectedChannel()
        }
        .task(id: selectedChannelID) {
            guard let selectedChannelID else { return }
            if videosByChannelID[selectedChannelID] == nil {
                videosByChannelID[selectedChannelID] = await coordinator.loadVideosForChannel(selectedChannelID)
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
    }

    private func applyDefaultSelectionIfNeeded() {
        if let selectedChannelID, items.contains(where: { $0.channelID == selectedChannelID }) {
            return
        }
        self.selectedChannelID = items.first?.channelID
    }

    private func refreshSelectedChannel() async {
        guard let selectedChannelID else { return }
        await coordinator.refreshChannelManually(selectedChannelID)
        videosByChannelID[selectedChannelID] = await coordinator.loadVideosForChannel(selectedChannelID)
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
        InteractiveListScreen(
            title: "動画一覧",
            subtitle: "キャッシュ済み動画を新しい順に最大50件表示",
            coordinator: coordinator,
            path: $path,
            layout: layout,
            onRefresh: nil
        ) {
            if coordinator.videos.isEmpty {
                MetricTile(title: "動画一覧", value: "まだありません", detail: "収集が進むとここに長尺動画を最大50件まで表示します")
            } else {
                LazyVGrid(columns: layout.listColumns, spacing: layout.isPad ? 20 : 14) {
                    ForEach(coordinator.videos) { video in
                        LongPressVideoTile(
                            video: video,
                            openVideo: {
                                openVideo(video)
                            },
                            removeChannel: {
                                pendingChannelRemoval = PendingChannelRemoval(
                                    channelID: video.channelID,
                                    channelTitle: video.channelTitle.isEmpty ? video.channelID : video.channelTitle
                                )
                            }
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

struct KeywordSearchResultsView: View {
    let keyword: String
    let coordinator: FeedCacheCoordinator
    let openVideo: (CachedVideo) -> Void
    @Binding var path: NavigationPath
    let layout: AppLayout

    @State private var result = VideoSearchResult(keyword: "", videos: [], totalCount: 0)
    @State private var isChipVisible = true

    var body: some View {
        InteractiveListScreen(
            title: "検索結果",
            subtitle: "「\(keyword)」に一致する動画を新しい順に20件表示",
            coordinator: coordinator,
            path: $path,
            layout: layout,
            onRefresh: {
                await reloadResults()
                dismissChip()
            }
        ) {
            if result.videos.isEmpty {
                MetricTile(title: "検索結果", value: "0件", detail: "一致する動画がキャッシュにありません")
            } else {
                LazyVGrid(columns: layout.listColumns, spacing: layout.isPad ? 20 : 14) {
                    ForEach(result.videos) { video in
                        LongPressVideoTile(
                            video: video,
                            openVideo: {
                                dismissChip()
                                openVideo(video)
                            },
                            removeChannel: nil
                        )
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isChipVisible {
                SearchResultCountChip(totalCount: result.totalCount, sourceLabel: result.source.label)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 1)
                .onChanged { _ in
                    dismissChip()
                }
        )
        .task {
            await reloadResults()
            scheduleChipDismiss()
        }
        .onAppear {
            StartupDiagnostics.shared.mark("keywordSearchShown")
        }
    }

    private func reloadResults() async {
        result = await coordinator.searchVideos(keyword: keyword, limit: 20)
    }

    private func scheduleChipDismiss() {
        Task {
            try? await Task.sleep(for: .seconds(4))
            await MainActor.run {
                dismissChip()
            }
        }
    }

    private func dismissChip() {
        guard isChipVisible else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            isChipVisible = false
        }
    }
}

private struct SearchResultCountChip: View {
    let totalCount: Int
    let sourceLabel: String

    var body: some View {
        HStack(spacing: 8) {
            Text("検索結果 \(totalCount) 件")
            Text(sourceLabel)
                .foregroundStyle(.secondary)
        }
        .font(.footnote.weight(.semibold))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(0.35), lineWidth: 1)
            }
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .accessibilityIdentifier("search.resultChip")
    }
}

struct RemoteKeywordSearchResultsView: View {
    let keyword: String
    let coordinator: FeedCacheCoordinator
    let openVideo: (CachedVideo) -> Void
    @Binding var path: NavigationPath
    let layout: AppLayout

    @State private var result = VideoSearchResult(keyword: "", videos: [], totalCount: 0)
    @State private var isChipVisible = true

    var body: some View {
        InteractiveListScreen(
            title: "YouTube検索",
            subtitle: "「\(keyword)」を YouTube で検索し、新しい順に20件表示",
            coordinator: coordinator,
            path: $path,
            layout: layout,
            onRefresh: {
                await reloadResults(forceRefresh: true)
                dismissChip()
            }
        ) {
            if let errorMessage = result.errorMessage, result.videos.isEmpty {
                MetricTile(title: "YouTube検索", value: "取得できません", detail: errorMessage)
            } else if result.videos.isEmpty {
                MetricTile(title: "YouTube検索", value: "0件", detail: "一致する動画が見つかりませんでした")
            } else {
                LazyVGrid(columns: layout.listColumns, spacing: layout.isPad ? 20 : 14) {
                    ForEach(result.videos) { video in
                        LongPressVideoTile(
                            video: video,
                            openVideo: {
                                dismissChip()
                                openVideo(video)
                            },
                            removeChannel: nil
                        )
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isChipVisible {
                SearchResultCountChip(totalCount: result.totalCount, sourceLabel: result.source.label)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 1)
                .onChanged { _ in
                    dismissChip()
                }
        )
        .task {
            await reloadResults(forceRefresh: false)
            scheduleChipDismiss()
        }
        .onAppear {
            StartupDiagnostics.shared.mark("keywordSearchShown")
        }
    }

    private func reloadResults(forceRefresh: Bool) async {
        result = await coordinator.searchRemoteVideos(keyword: keyword, limit: 20, forceRefresh: forceRefresh)
        isChipVisible = true
    }

    private func scheduleChipDismiss() {
        Task {
            try? await Task.sleep(for: .seconds(4))
            await MainActor.run {
                dismissChip()
            }
        }
    }

    private func dismissChip() {
        guard isChipVisible else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            isChipVisible = false
        }
    }
}

struct ChannelVideosView: View {
    let channelID: String
    let coordinator: FeedCacheCoordinator
    let openVideo: (CachedVideo) -> Void
    @Binding var path: NavigationPath
    let layout: AppLayout

    @State private var videos: [CachedVideo] = []
    @State private var pendingChannelRemoval: PendingChannelRemoval?
    @State private var removalFeedback: ChannelRemovalFeedback?

    var body: some View {
        InteractiveListScreen(
            title: channelTitle,
            subtitle: "このチャンネルの動画を新しい順に最大50件表示",
            coordinator: coordinator,
            path: $path,
            layout: layout,
            onRefresh: {
                await coordinator.refreshChannelManually(channelID)
                await reloadVideos()
            }
        ) {
            if AppLaunchMode.current.usesMockData {
                UITestMarker(
                    identifier: "screen.channelVideos.loaded",
                    value: videos.first?.id ?? "none"
                )
                UITestMarker(
                    identifier: "test.channelRefreshTarget",
                    value: coordinator.lastManualChannelRefreshID ?? "none"
                )
            }

            if videos.isEmpty {
                MetricTile(title: "動画一覧", value: "まだありません", detail: "このチャンネルのキャッシュがあるとここに表示します")
            } else {
                LazyVGrid(columns: layout.listColumns, spacing: layout.isPad ? 20 : 14) {
                    ForEach(videos) { video in
                        LongPressVideoTile(
                            video: video,
                            openVideo: {
                                openVideo(video)
                            },
                            removeChannel: {
                                pendingChannelRemoval = PendingChannelRemoval(
                                    channelID: video.channelID,
                                    channelTitle: video.channelTitle.isEmpty ? video.channelID : video.channelTitle
                                )
                            }
                        )
                    }
                }
            }
        }
        .task {
            await reloadVideos()
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
                dismissButton: .default(Text("OK")) {
                    if !path.isEmpty {
                        path.removeLast()
                    }
                }
            )
        }
        .onAppear {
            StartupDiagnostics.shared.mark("channelVideosShown")
        }
    }

    private var channelTitle: String {
        coordinator.maintenanceItems.first(where: { $0.channelID == channelID })?.channelTitle ?? channelID
    }

    private func reloadVideos() async {
        videos = await coordinator.loadVideosForChannel(channelID)
    }
}
