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
                        VideoTile(
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
                .onChanged { value in
                    if shouldDismissChip(for: value) {
                        dismissChip()
                    }
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

    private func shouldDismissChip(for value: DragGesture.Value) -> Bool {
        value.translation.height < -8 || abs(value.translation.width) > 20
    }

    private func normalizedChannelTitle(for video: CachedVideo) -> String? {
        video.channelTitle.isEmpty ? nil : video.channelTitle
    }
}

private struct SearchResultCountChip: View {
    let totalCount: Int
    let sourceLabel: String
    let fetchedAt: Date?
    let isRefreshing: Bool

    init(totalCount: Int, sourceLabel: String, fetchedAt: Date?, isRefreshing: Bool = false) {
        self.totalCount = totalCount
        self.sourceLabel = sourceLabel
        self.fetchedAt = fetchedAt
        self.isRefreshing = isRefreshing
    }

    var body: some View {
        HStack(spacing: 8) {
            if isRefreshing {
                ProgressView()
                    .controlSize(.small)
                Text("再検索中")
            } else {
                if let fetchedAt {
                    Text("最終更新 \(Self.timestampFormatter.string(from: fetchedAt))")
                }
                Text("\(totalCount) 件")
                Text(sourceLabel)
                    .foregroundStyle(.secondary)
            }
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
        .accessibilityLabel(isRefreshing ? "再検索中" : accessibilitySummary)
        .overlay {
            if AppLaunchMode.current.usesMockData {
                UITestMarker(
                    identifier: "search.resultChip.state",
                    value: isRefreshing ? "refreshing" : "summary"
                )
            }
        }
    }

    private var accessibilitySummary: String {
        let updatedText = fetchedAt.map { "最終更新 \(Self.timestampFormatter.string(from: $0))" } ?? "更新時刻なし"
        return "\(updatedText) \(totalCount) 件 \(sourceLabel)"
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d HH:mm"
        return formatter
    }()
}

private struct SearchRefreshStatusView: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("YouTube を再検索中")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("search.refreshIndicator")
    }
}

struct RemoteKeywordSearchResultsView: View {
    let keyword: String
    let coordinator: FeedCacheCoordinator
    let openVideo: (CachedVideo) -> Void
    @Binding var path: NavigationPath
    let layout: AppLayout

    @State private var result = VideoSearchResult(keyword: "", videos: [], totalCount: 0)
    @State private var presentationState = RemoteSearchPresentationState(
        visibleCount: 20,
        chipMode: .hidden,
        splitContext: nil
    )
    @State private var splitContext: ChannelVideosRouteContext?
    @State private var splitVideos: [CachedVideo] = []

    var body: some View {
        Group {
            if layout.usesSplitChannelBrowser {
                RemoteKeywordSearchResultsRegularView(
                    keyword: keyword,
                    coordinator: coordinator,
                    openVideo: openVideo,
                    path: $path,
                    layout: layout,
                    result: result,
                    visibleCount: presentationState.visibleCount,
                    splitContext: $splitContext,
                    splitVideos: $splitVideos,
                    onRefresh: { await reloadResults(forceRefresh: true) },
                    onDismissChip: dismissChip,
                    onLoadMore: loadMoreIfNeeded,
                    normalizedChannelTitle: normalizedChannelTitle(for:)
                )
            } else {
                RemoteKeywordSearchResultsCompactView(
                    coordinator: coordinator,
                    layout: layout,
                    path: $path,
                    keyword: keyword,
                    result: result,
                    visibleCount: presentationState.visibleCount,
                    onRefresh: { await reloadResults(forceRefresh: true) },
                    onDismissChip: dismissChip,
                    onLoadMore: loadMoreIfNeeded,
                    normalizedChannelTitle: normalizedChannelTitle(for:)
                )
            }
        }
        .overlay(alignment: .top) {
            if presentationState.isRefreshingChip {
                SearchRefreshStatusView()
                    .padding(.horizontal, layout.horizontalPadding)
                    .padding(.top, 12)
            }
        }
        .overlay(alignment: .topTrailing) {
            VStack(alignment: .trailing, spacing: 4) {
                if AppLaunchMode.current.usesMockData {
                    UITestMarker(
                        identifier: "test.remoteSearch.firstVideoID",
                        value: result.videos.first?.id ?? "none"
                    )
                    UITestMarker(
                        identifier: "search.refreshPhase",
                        value: presentationState.chipMode.rawValue
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
            if presentationState.chipMode == .summary {
                SearchResultCountChip(
                    totalCount: result.totalCount,
                    sourceLabel: result.source.label,
                    fetchedAt: result.fetchedAt,
                    isRefreshing: presentationState.isRefreshingChip
                )
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if shouldDismissChip(for: value) {
                        dismissChip()
                    }
                }
        )
        .task {
            await loadSnapshot()
        }
        .onAppear {
            StartupDiagnostics.shared.mark("keywordSearchShown")
            AppConsoleLogger.youtubeSearch.info(
                "screen_appear",
                metadata: ["keyword": AppConsoleLogger.sanitizedKeyword(keyword)]
            )
        }
        .onDisappear {
            AppConsoleLogger.youtubeSearch.info(
                "screen_disappear",
                metadata: [
                    "keyword": AppConsoleLogger.sanitizedKeyword(keyword),
                    "videos": String(result.videos.count),
                    "refreshing": presentationState.isRefreshingChip ? "true" : "false",
                ]
            )
        }
    }

    private func loadSnapshot() async {
        let logger = AppConsoleLogger.youtubeSearch
        let keywordPreview = AppConsoleLogger.sanitizedKeyword(keyword)
        logger.debug("screen_snapshot_load_start", metadata: ["keyword": keywordPreview])
        result = await coordinator.loadRemoteSearchSnapshot(keyword: keyword, limit: 100)
        logger.debug(
            "screen_snapshot_load_complete",
            metadata: [
                "keyword": keywordPreview,
                "source": result.source.label,
                "videos": String(result.videos.count),
                "error": result.errorMessage == nil ? "none" : "present",
            ]
        )
        applyPresentationState()
    }

    private func reloadResults(forceRefresh: Bool) async {
        let logger = AppConsoleLogger.youtubeSearch
        let keywordPreview = AppConsoleLogger.sanitizedKeyword(keyword)
        logger.info(
            "screen_refresh_start",
            metadata: [
                "keyword": keywordPreview,
                "force_refresh": forceRefresh ? "true" : "false",
                "current_videos": String(result.videos.count),
            ]
        )
        if forceRefresh {
            presentationState.beginRefresh()
            await Task.yield()
        }
        result = await coordinator.searchRemoteVideos(keyword: keyword, limit: 100, forceRefresh: forceRefresh)
        logger.notice(
            "screen_refresh_complete",
            metadata: [
                "keyword": keywordPreview,
                "source": result.source.label,
                "videos": String(result.videos.count),
                "fetched": result.fetchedAt == nil ? "false" : "true",
                "error": result.errorMessage == nil ? "none" : "present",
            ]
        )
        applyPresentationState()
    }

    private func dismissChip() {
        guard presentationState.isChipVisible else { return }
        guard presentationState.chipMode != .refreshing else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            presentationState.dismissChip()
        }
    }

    private func shouldDismissChip(for value: DragGesture.Value) -> Bool {
        value.translation.height < -8 || abs(value.translation.width) > 20
    }

    private func loadMoreIfNeeded() {
        presentationState.loadMoreIfNeeded(totalVideoCount: result.videos.count)
    }

    private func applyPresentationState() {
        presentationState = RemoteSearchPresentationState.build(
            result: result,
            usesSplitChannelBrowser: layout.usesSplitChannelBrowser,
            previousSplitContext: splitContext
        )
        if layout.usesSplitChannelBrowser {
            applyDefaultSplitSelectionIfNeeded()
        }
    }

    private func applyDefaultSplitSelectionIfNeeded() {
        guard layout.usesSplitChannelBrowser else { return }
        guard let context = presentationState.splitContext else {
            splitContext = nil
            splitVideos = []
            return
        }
        if splitContext == context { return }
        Task {
            await selectSplitContext(context)
        }
    }

    private func selectSplitVideo(_ video: CachedVideo) async {
        await selectSplitContext(
            ChannelVideosRouteContext(
                channelID: video.channelID,
                preferredChannelTitle: normalizedChannelTitle(for: video),
                selectedVideoID: video.id,
                prefersAutomaticRefresh: true
            )
        )
    }

    private func selectSplitContext(_ context: ChannelVideosRouteContext) async {
        splitContext = context
        splitVideos = await coordinator.openChannelVideos(context)
    }

    private func normalizedChannelTitle(for video: CachedVideo) -> String? {
        video.channelTitle.isEmpty ? nil : video.channelTitle
    }
}

private struct RemoteKeywordSearchResultsCompactView: View {
    let coordinator: FeedCacheCoordinator
    let layout: AppLayout
    @Binding var path: NavigationPath
    let keyword: String
    let result: VideoSearchResult
    let visibleCount: Int
    let onRefresh: () async -> Void
    let onDismissChip: () -> Void
    let onLoadMore: () -> Void
    let normalizedChannelTitle: (CachedVideo) -> String?

    var body: some View {
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
                        VideoTile(
                            video: video,
                            tapAction: {
                                onDismissChip()
                                path.append(
                                    MaintenanceRoute.channelVideos(
                                        ChannelVideosRouteContext(
                                            channelID: video.channelID,
                                            preferredChannelTitle: normalizedChannelTitle(video),
                                            selectedVideoID: video.id,
                                            prefersAutomaticRefresh: true
                                        )
                                    )
                                )
                            },
                            openVideoAction: nil,
                            removeChannel: nil,
                            index: offset + 1
                        )
                        .onAppear {
                            guard offset >= visibleVideos.count - 1 else { return }
                            onLoadMore()
                        }
                    }
                }
            }
        }
    }
}

private struct RemoteKeywordSearchResultsRegularView: View {
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
                            VideoTile(
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
                                index: offset + 1
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
                                VideoTile(
                                    video: video,
                                    tapAction: nil,
                                    openVideoAction: {
                                        openVideo(video)
                                    },
                                    removeChannel: nil,
                                    index: offset + 1
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
