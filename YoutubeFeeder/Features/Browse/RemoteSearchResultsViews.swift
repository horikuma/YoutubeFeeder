import SwiftUI

enum RemoteSearchPresentationMode: String {
    case visible
    case prewarm
}

struct RemoteKeywordSearchResultsView: View {
    let keyword: String
    let coordinator: FeedCacheCoordinator
    let openVideo: (CachedVideo) -> Void
    @Binding var path: NavigationPath
    let layout: AppLayout
    let browsePresentation: BasicGUIBrowsePresentation
    let presentationMode: RemoteSearchPresentationMode

    @State private var result = VideoSearchResult(keyword: "", videos: [], totalCount: 0)
    @State private var presentationState = RemoteSearchPresentationState(
        visibleCount: 20,
        chipMode: .hidden,
        splitContext: nil
    )
    @State private var splitContext: ChannelVideosRouteContext?
    @State private var splitVideos: [CachedVideo] = []
    @State private var splitVisibleCount = 20
    @State private var splitLoadTask: Task<Void, Never>?
    @State private var isSplitLoading = false
    @State private var hasLoggedRootRender = false

    init(
        keyword: String,
        coordinator: FeedCacheCoordinator,
        openVideo: @escaping (CachedVideo) -> Void,
        path: Binding<NavigationPath>,
        layout: AppLayout,
        browsePresentation: BasicGUIBrowsePresentation,
        presentationMode: RemoteSearchPresentationMode = .visible
    ) {
        self.keyword = keyword
        self.coordinator = coordinator
        self.openVideo = openVideo
        _path = path
        self.layout = layout
        self.browsePresentation = browsePresentation
        self.presentationMode = presentationMode
    }

    var body: some View {
        content
            .background(
                RenderProbe {
                    guard !hasLoggedRootRender else { return }
                    hasLoggedRootRender = true
                    recordRenderProbe("root")
                }
                .frame(width: 0, height: 0)
            )
            .overlay(alignment: .top) {
                if presentationState.isRefreshingChip {
                    SearchRefreshStatusView()
                        .padding(.horizontal, layout.horizontalPadding)
                        .padding(.top, 12)
                }
            }
            .overlay(alignment: .topTrailing) {
                remoteSearchTestControls
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
                RuntimeDiagnostics.shared.record(
                    "remote_search_screen_shown",
                    detail: "YouTube検索画面を表示",
                    metadata: [
                        "keyword": keyword,
                        "layout": browsePresentation.rawValue,
                        "mode": presentationMode.rawValue,
                    ]
                )
                AppConsoleLogger.youtubeSearch.info(
                    "screen_appear",
                    metadata: [
                        "keyword": AppConsoleLogger.sanitizedKeyword(keyword),
                        "mode": presentationMode.rawValue,
                    ]
                )
            }
            .onDisappear {
                splitLoadTask?.cancel()
                AppConsoleLogger.youtubeSearch.info(
                    "screen_disappear",
                    metadata: [
                        "keyword": AppConsoleLogger.sanitizedKeyword(keyword),
                        "videos": String(result.videos.count),
                        "refreshing": presentationState.isRefreshingChip ? "true" : "false",
                        "mode": presentationMode.rawValue,
                    ]
                )
            }
    }

    private var remoteSearchTestControls: some View {
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

    private func loadSnapshot() async {
        let logger = AppConsoleLogger.youtubeSearch
        let keywordPreview = AppConsoleLogger.sanitizedKeyword(keyword)
        let startedAt = Date()
        logger.debug(
            "screen_snapshot_load_start",
            metadata: [
                "keyword": keywordPreview,
                "limit": "100",
                "mode": presentationMode.rawValue,
            ]
        )
        result = await coordinator.loadRemoteSearchSnapshot(keyword: keyword, limit: 100)
        logger.debug(
            "screen_snapshot_load_complete",
            metadata: [
                "keyword": keywordPreview,
                "source": result.source.label,
                "videos": String(result.videos.count),
                "error": result.errorMessage == nil ? "none" : "present",
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                "mode": presentationMode.rawValue,
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
                "mode": presentationMode.rawValue,
            ]
        )
        if forceRefresh {
            presentationState.beginRefresh()
            await Task.yield()
        }
        if forceRefresh {
            if case let .remoteSearch(refreshedResult) = await coordinator.performRefreshAction(.remoteSearch(keyword: keyword, limit: 100)) {
                result = refreshedResult
            }
        } else {
            result = await coordinator.searchRemoteVideos(keyword: keyword, limit: 100, forceRefresh: false)
        }
        logger.notice(
            "screen_refresh_complete",
            metadata: [
                "keyword": keywordPreview,
                "source": result.source.label,
                "videos": String(result.videos.count),
                "fetched": result.fetchedAt == nil ? "false" : "true",
                "error": result.errorMessage == nil ? "none" : "present",
                "mode": presentationMode.rawValue,
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
            usesSplitChannelBrowser: browsePresentation.usesSplitLayout,
            previousSplitContext: splitContext
        )
        if browsePresentation.usesSplitLayout {
            applyDefaultSplitSelectionIfNeeded()
        }
    }

    private func applyDefaultSplitSelectionIfNeeded() {
        guard browsePresentation.usesSplitLayout else { return }
        guard let context = presentationState.splitContext else {
            splitLoadTask?.cancel()
            splitContext = nil
            splitVideos = []
            splitVisibleCount = 20
            isSplitLoading = false
            return
        }
        if splitContext == context { return }
        scheduleDeferredSplitSelection(context)
    }

    private func selectSplitChannel(_ context: ChannelVideosRouteContext) {
        splitLoadTask?.cancel()
        beginDeferredSplitSelection(context)

        splitLoadTask = Task {
            await performImmediateSplitSelection(context)
        }
    }

    private func scheduleDeferredSplitSelection(_ context: ChannelVideosRouteContext) {
        splitLoadTask?.cancel()
        beginDeferredSplitSelection(context)
        let scheduledAt = Date()
        recordDeferredSplitSelectionScheduled(context)

        splitLoadTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            await performDeferredSplitSelection(context, scheduledAt: scheduledAt)
        }
    }

    private func beginDeferredSplitSelection(_ context: ChannelVideosRouteContext) {
        splitContext = context
        splitVideos = []
        splitVisibleCount = 20
        isSplitLoading = true
    }

    private func performImmediateSplitSelection(_ context: ChannelVideosRouteContext) async {
        let startedAt = Date()
        AppConsoleLogger.appLifecycle.info(
            "remote_search_split_load_started",
            metadata: [
                "channelID": context.channelID,
                "trigger": "tap",
                "scheduled_wait_ms": "0",
                "mode": presentationMode.rawValue,
            ]
        )
        RuntimeDiagnostics.shared.record(
            "remote_search_split_load_started",
            detail: "YouTube検索右ペインの読込を開始",
            metadata: [
                "channelID": context.channelID,
                "trigger": "tap",
                "mode": presentationMode.rawValue,
            ]
        )

        let loadedVideos = await coordinator.openChannelVideos(context)
        guard !Task.isCancelled else { return }

        let publishStartedAt = Date()
        await MainActor.run {
            guard splitContext == context else { return }
            splitVideos = loadedVideos
            splitVisibleCount = min(20, loadedVideos.count)
            isSplitLoading = false
        }

        AppConsoleLogger.appLifecycle.notice(
            "remote_search_split_load_completed",
            metadata: [
                "channelID": context.channelID,
                "trigger": "tap",
                "videos": String(loadedVideos.count),
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                "publish_ms": AppConsoleLogger.elapsedMilliseconds(from: publishStartedAt, to: Date()),
                "mode": presentationMode.rawValue,
            ]
        )
        RuntimeDiagnostics.shared.record(
            "remote_search_split_load_completed",
            detail: "YouTube検索右ペインの読込を完了",
            metadata: [
                "channelID": context.channelID,
                "trigger": "tap",
                "videos": String(loadedVideos.count),
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                "mode": presentationMode.rawValue,
            ]
        )
    }

    private func recordDeferredSplitSelectionScheduled(_ context: ChannelVideosRouteContext) {
        RuntimeDiagnostics.shared.record(
            "remote_search_split_load_scheduled",
            detail: "YouTube検索右ペインの初期読込を予約",
            metadata: [
                "channelID": context.channelID,
                "delay_ms": "150",
                "mode": presentationMode.rawValue,
            ]
        )
    }

    private func performDeferredSplitSelection(_ context: ChannelVideosRouteContext, scheduledAt: Date) async {
        let startedAt = Date()
        recordDeferredSplitSelectionStarted(context, scheduledAt: scheduledAt, startedAt: startedAt)
        let loadedVideos = await coordinator.openChannelVideos(context)
        guard !Task.isCancelled else { return }

        let publishStartedAt = Date()
        await MainActor.run {
            guard splitContext == context else { return }
            splitVideos = loadedVideos
            splitVisibleCount = min(20, loadedVideos.count)
            isSplitLoading = false
        }
        recordDeferredSplitSelectionCompleted(
            context,
            loadedVideos: loadedVideos,
            startedAt: startedAt,
            publishStartedAt: publishStartedAt
        )
    }

    private func recordDeferredSplitSelectionStarted(
        _ context: ChannelVideosRouteContext,
        scheduledAt: Date,
        startedAt: Date
    ) {
        AppConsoleLogger.appLifecycle.info(
            "remote_search_split_load_started",
            metadata: [
                "channelID": context.channelID,
                "trigger": "initial",
                "scheduled_wait_ms": AppConsoleLogger.elapsedMilliseconds(from: scheduledAt, to: startedAt),
                "mode": presentationMode.rawValue,
            ]
        )
        RuntimeDiagnostics.shared.record(
            "remote_search_split_load_started",
            detail: "YouTube検索右ペインの読込を開始",
            metadata: [
                "channelID": context.channelID,
                "trigger": "initial",
                "mode": presentationMode.rawValue,
            ]
        )
    }

    private func recordDeferredSplitSelectionCompleted(
        _ context: ChannelVideosRouteContext,
        loadedVideos: [CachedVideo],
        startedAt: Date,
        publishStartedAt: Date
    ) {
        AppConsoleLogger.appLifecycle.notice(
            "remote_search_split_load_completed",
            metadata: [
                "channelID": context.channelID,
                "trigger": "initial",
                "videos": String(loadedVideos.count),
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                "publish_ms": AppConsoleLogger.elapsedMilliseconds(from: publishStartedAt, to: Date()),
                "mode": presentationMode.rawValue,
            ]
        )
        RuntimeDiagnostics.shared.record(
            "remote_search_split_load_completed",
            detail: "YouTube検索右ペインの読込を完了",
            metadata: [
                "channelID": context.channelID,
                "trigger": "initial",
                "videos": String(loadedVideos.count),
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                "mode": presentationMode.rawValue,
            ]
        )
    }

    private func normalizedChannelTitle(for video: CachedVideo) -> String? {
        video.channelTitle.isEmpty ? nil : video.channelTitle
    }

    private func loadMoreSplitVideosIfNeeded() {
        guard splitVisibleCount < splitVideos.count else { return }
        splitVisibleCount = min(splitVisibleCount + 20, splitVideos.count)
    }

    private func recordRenderProbe(_ phase: String) {
        let metadata = [
            "phase": phase,
            "layout": browsePresentation.rawValue,
            "mode": presentationMode.rawValue,
            "videos": String(result.videos.count),
        ]
        AppConsoleLogger.youtubeSearch.debug("screen_render_probe", metadata: metadata)
        RuntimeDiagnostics.shared.record(
            "remote_search_render_probe",
            detail: "YouTube検索画面の描画到達点",
            metadata: metadata
        )
    }

    @ViewBuilder
    private var content: some View {
        if browsePresentation.usesSplitLayout {
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
                splitVisibleCount: $splitVisibleCount,
                isSplitLoading: isSplitLoading,
                presentationMode: presentationMode,
                onRenderProbe: recordRenderProbe,
                onLoadMoreSplitVideos: loadMoreSplitVideosIfNeeded,
                onSelectSplitChannel: selectSplitChannel,
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
                allowsRefreshCommandBinding: presentationMode == .visible,
                onRefresh: { await reloadResults(forceRefresh: true) },
                onDismissChip: dismissChip,
                onLoadMore: loadMoreIfNeeded,
                normalizedChannelTitle: normalizedChannelTitle(for:)
            )
        }
    }
}
