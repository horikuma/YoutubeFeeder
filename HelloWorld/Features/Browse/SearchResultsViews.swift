import SwiftUI

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
            }
        ) {
            if result.videos.isEmpty {
                MetricTile(title: "検索結果", value: "0件", detail: "一致する動画がキャッシュにありません")
            } else {
                LazyVGrid(columns: layout.listColumns, spacing: layout.isPad ? 20 : 14) {
                    ForEach(Array(result.videos.enumerated()), id: \.element.id) { offset, video in
                        LongPressVideoTile(
                            video: video,
                            tapAction: {
                                dismissChip()
                                path.append(
                                    MaintenanceRoute.channelVideos(
                                        ChannelVideosRouteContext(
                                            channelID: video.channelID,
                                            preferredChannelTitle: normalizedChannelTitle(for: video),
                                            selectedVideoID: video.id
                                        )
                                    )
                                )
                            },
                            openVideoAction: nil,
                            removeChannel: nil,
                            index: offset + 1
                        )
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isChipVisible {
                SearchResultCountChip(totalCount: result.totalCount, sourceLabel: result.source.label, fetchedAt: result.fetchedAt)
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
        }
        .onAppear {
            StartupDiagnostics.shared.mark("keywordSearchShown")
        }
    }

    private func reloadResults() async {
        result = await coordinator.searchVideos(keyword: keyword, limit: 20)
    }

    private func dismissChip() {
        guard isChipVisible else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            isChipVisible = false
        }
    }

    private func normalizedChannelTitle(for video: CachedVideo) -> String? {
        video.channelTitle.isEmpty ? nil : video.channelTitle
    }
}

private struct SearchResultCountChip: View {
    let totalCount: Int
    let sourceLabel: String
    let fetchedAt: Date?

    var body: some View {
        HStack(spacing: 8) {
            if let fetchedAt {
                Text("最終更新 \(Self.timestampFormatter.string(from: fetchedAt))")
            }
            Text("\(totalCount) 件")
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

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d HH:mm"
        return formatter
    }()
}

struct RemoteKeywordSearchResultsView: View {
    let keyword: String
    let coordinator: FeedCacheCoordinator
    let openVideo: (CachedVideo) -> Void
    @Binding var path: NavigationPath
    let layout: AppLayout

    @State private var result = VideoSearchResult(keyword: "", videos: [], totalCount: 0)
    @State private var isChipVisible = true
    @State private var visibleCount = 20
    @State private var splitContext: ChannelVideosRouteContext?
    @State private var splitVideos: [CachedVideo] = []

    var body: some View {
        Group {
            if layout.usesSplitChannelBrowser {
                SplitRemoteKeywordSearchResultsView(
                    keyword: keyword,
                    coordinator: coordinator,
                    openVideo: openVideo,
                    path: $path,
                    layout: layout,
                    result: result,
                    visibleCount: visibleCount,
                    splitContext: $splitContext,
                    splitVideos: $splitVideos,
                    onRefresh: { await reloadResults(forceRefresh: true) },
                    onDismissChip: dismissChip,
                    onLoadMore: loadMoreIfNeeded,
                    normalizedChannelTitle: normalizedChannelTitle(for:)
                )
            } else {
                InteractiveListScreen(
                    title: "YouTube検索",
                    subtitle: "下に引っ張ると「\(keyword)」を YouTube で検索し、履歴を順次マージして表示",
                    coordinator: coordinator,
                    path: $path,
                    layout: layout,
                    onRefresh: {
                        await reloadResults(forceRefresh: true)
                    }
                ) {
                    remoteSearchListContent(
                        videos: Array(result.videos.prefix(visibleCount)),
                        useNavigation: true
                    )
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            VStack(alignment: .trailing, spacing: 4) {
                if AppLaunchMode.current.usesMockData {
                    UITestMarker(
                        identifier: "test.remoteSearch.firstVideoID",
                        value: result.videos.first?.id ?? "none"
                    )
                    UITestAsyncActionTrigger(identifier: "test.remoteSearch.refresh") {
                        await reloadResults(forceRefresh: true)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.trailing, 8)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if result.totalCount > 0 {
                    Button("クリア") {
                        Task {
                            await coordinator.clearRemoteSearchHistory(keyword: keyword)
                            await loadSnapshot()
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isChipVisible, result.fetchedAt != nil {
                SearchResultCountChip(totalCount: result.totalCount, sourceLabel: result.source.label, fetchedAt: result.fetchedAt)
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
            await loadSnapshot()
        }
        .onAppear {
            StartupDiagnostics.shared.mark("keywordSearchShown")
        }
    }

    private func loadSnapshot() async {
        result = await coordinator.loadRemoteSearchSnapshot(keyword: keyword, limit: 100)
        visibleCount = min(20, max(result.videos.count, 20))
        isChipVisible = result.fetchedAt != nil
        if layout.usesSplitChannelBrowser {
            applyDefaultSplitSelectionIfNeeded()
        }
    }

    private func reloadResults(forceRefresh: Bool) async {
        result = await coordinator.searchRemoteVideos(keyword: keyword, limit: 100, forceRefresh: forceRefresh)
        visibleCount = min(20, max(result.videos.count, 20))
        isChipVisible = result.fetchedAt != nil
        if layout.usesSplitChannelBrowser {
            applyDefaultSplitSelectionIfNeeded()
        }
    }

    private func dismissChip() {
        guard isChipVisible else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            isChipVisible = false
        }
    }

    private func loadMoreIfNeeded() {
        guard visibleCount < result.videos.count else { return }
        visibleCount = min(visibleCount + 20, result.videos.count)
    }

    private func applyDefaultSplitSelectionIfNeeded() {
        guard layout.usesSplitChannelBrowser else { return }
        if let splitContext, result.videos.contains(where: { $0.channelID == splitContext.channelID }) {
            return
        }
        guard let firstVideo = result.videos.first else {
            splitContext = nil
            splitVideos = []
            return
        }
        Task {
            await selectSplitVideo(firstVideo)
        }
    }

    private func selectSplitVideo(_ video: CachedVideo) async {
        let context = ChannelVideosRouteContext(
            channelID: video.channelID,
            preferredChannelTitle: normalizedChannelTitle(for: video),
            selectedVideoID: video.id,
            prefersAutomaticRefresh: true
        )
        splitContext = context
        splitVideos = await coordinator.openChannelVideos(context)
    }

    @ViewBuilder
    private func remoteSearchListContent(videos: [CachedVideo], useNavigation: Bool) -> some View {
        if result.fetchedAt == nil, result.videos.isEmpty, result.errorMessage == nil {
            MetricTile(
                title: "YouTube検索",
                value: "未取得",
                detail: "この画面で下に引っ張ると検索します。結果はキャッシュされ、次回はその内容を表示します"
            )
        } else if let errorMessage = result.errorMessage, result.videos.isEmpty {
            MetricTile(title: "YouTube検索", value: "取得できません", detail: errorMessage)
        } else if result.videos.isEmpty {
            MetricTile(title: "YouTube検索", value: "0件", detail: "一致する動画が見つかりませんでした")
        } else {
            LazyVGrid(columns: layout.listColumns, spacing: layout.isPad ? 20 : 14) {
                ForEach(Array(videos.enumerated()), id: \.element.id) { offset, video in
                    LongPressVideoTile(
                        video: video,
                        tapAction: {
                            dismissChip()
                            if useNavigation {
                                path.append(
                                    MaintenanceRoute.channelVideos(
                                        ChannelVideosRouteContext(
                                            channelID: video.channelID,
                                            preferredChannelTitle: normalizedChannelTitle(for: video),
                                            selectedVideoID: video.id,
                                            prefersAutomaticRefresh: true
                                        )
                                    )
                                )
                            } else {
                                Task {
                                    await selectSplitVideo(video)
                                }
                            }
                        },
                        openVideoAction: nil,
                        removeChannel: nil,
                        index: offset
                    )
                    .onAppear {
                        guard offset >= videos.count - 1 else { return }
                        loadMoreIfNeeded()
                    }
                }
            }
        }
    }

    private func normalizedChannelTitle(for video: CachedVideo) -> String? {
        video.channelTitle.isEmpty ? nil : video.channelTitle
    }
}

private struct SplitRemoteKeywordSearchResultsView: View {
    let keyword: String
    let coordinator: FeedCacheCoordinator
    let openVideo: (CachedVideo) -> Void
    @Binding var path: NavigationPath
    let layout: AppLayout
    let result: VideoSearchResult
    let visibleCount: Int
    @Binding var splitContext: ChannelVideosRouteContext?
    @Binding var splitVideos: [CachedVideo]
    let onRefresh: () async -> Void
    let onDismissChip: () -> Void
    let onLoadMore: () -> Void
    let normalizedChannelTitle: (CachedVideo) -> String?

    var body: some View {
        NavigationSplitView {
            InteractiveListScreen(
                title: "YouTube検索",
                subtitle: "下に引っ張ると「\(keyword)」を YouTube で検索し、履歴を順次マージして表示",
                coordinator: coordinator,
                path: $path,
                layout: layout,
                onRefresh: {
                    await onRefresh()
                }
            ) {
                if result.fetchedAt == nil, result.videos.isEmpty, result.errorMessage == nil {
                    MetricTile(
                        title: "YouTube検索",
                        value: "未取得",
                        detail: "この画面で下に引っ張ると検索します。結果はキャッシュされ、次回はその内容を表示します"
                    )
                } else if let errorMessage = result.errorMessage, result.videos.isEmpty {
                    MetricTile(title: "YouTube検索", value: "取得できません", detail: errorMessage)
                } else if result.videos.isEmpty {
                    MetricTile(title: "YouTube検索", value: "0件", detail: "一致する動画が見つかりませんでした")
                } else {
                    let visibleVideos = Array(result.videos.prefix(visibleCount))
                    LazyVGrid(columns: layout.listColumns, spacing: layout.isPad ? 20 : 14) {
                        ForEach(Array(visibleVideos.enumerated()), id: \.element.id) { offset, video in
                            LongPressVideoTile(
                                video: video,
                                tapAction: {
                                    onDismissChip()
                                    Task {
                                        let context = ChannelVideosRouteContext(
                                            channelID: video.channelID,
                                            preferredChannelTitle: normalizedChannelTitle(video),
                                            selectedVideoID: video.id,
                                            prefersAutomaticRefresh: true
                                        )
                                        await MainActor.run {
                                            splitContext = context
                                        }
                                        let loadedVideos = await coordinator.openChannelVideos(context)
                                        await MainActor.run {
                                            splitVideos = loadedVideos
                                        }
                                    }
                                },
                                openVideoAction: nil,
                                removeChannel: nil,
                                index: offset
                            )
                            .onAppear {
                                guard offset >= visibleVideos.count - 1 else { return }
                                onLoadMore()
                            }
                        }
                    }
                }
            }
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(splitTitle)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .accessibilityIdentifier("screen.remoteSearchSplitTitle")

                    Text("このチャンネルの動画を新しい順に最大50件表示")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if AppLaunchMode.current.usesMockData {
                        UITestMarker(
                            identifier: "test.remoteSearch.splitChannelID",
                            value: splitContext?.channelID ?? "none"
                        )
                        UITestMarker(
                            identifier: "screen.channelVideos.loaded",
                            value: splitVideos.first?.id ?? "none"
                        )
                    }

                    if splitContext == nil {
                        MetricTile(title: "チャンネル動画", value: "未選択", detail: "左側の動画をタップするとこのチャンネルの動画一覧を表示します")
                    } else if splitVideos.isEmpty {
                        MetricTile(title: "動画一覧", value: "まだありません", detail: "このチャンネルのキャッシュがあるとここに表示します")
                    } else {
                        LazyVGrid(columns: layout.listColumns, spacing: 20) {
                            ForEach(Array(splitVideos.enumerated()), id: \.element.id) { offset, video in
                                LongPressVideoTile(
                                    video: video,
                                    tapAction: nil,
                                    openVideoAction: {
                                        openVideo(video)
                                    },
                                    removeChannel: nil,
                                    index: offset
                                )
                            }
                        }
                    }
                }
                .frame(maxWidth: layout.readableContentWidth ?? layout.contentWidth ?? .infinity, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, layout.horizontalPadding)
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .refreshable {
                guard let splitContext else { return }
                await coordinator.refreshChannelManually(splitContext.channelID)
                splitVideos = await coordinator.openChannelVideos(splitContext)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(.hidden, for: .navigationBar)
        .modifier(BackSwipePopModifier(path: $path))
    }

    private var splitTitle: String {
        splitContext?.preferredChannelTitle ?? splitVideos.first(where: { !$0.channelTitle.isEmpty })?.channelTitle ?? splitContext?.channelID ?? "チャンネル未選択"
    }
}
