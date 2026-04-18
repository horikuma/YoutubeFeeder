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

    @State private var searchState = RemoteSearchLogic()
    @State private var splitLoadTask: Task<Void, Never>?
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
                if searchState.presentationState.isRefreshingChip {
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
                    if searchState.result.totalCount > 0 {
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
                if searchState.presentationState.chipMode == .summary {
                    SearchResultCountChip(
                        totalCount: searchState.result.totalCount,
                        sourceLabel: searchState.result.source.label,
                        fetchedAt: searchState.result.fetchedAt,
                        isRefreshing: searchState.presentationState.isRefreshingChip
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
                        "videos": String(searchState.result.videos.count),
                        "refreshing": searchState.presentationState.isRefreshingChip ? "true" : "false",
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
                    value: searchState.result.videos.first?.id ?? "none"
                )
                UITestMarker(
                    identifier: "search.refreshPhase",
                    value: searchState.presentationState.chipMode.rawValue
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
        let loadedResult = await coordinator.loadRemoteSearchSnapshot(keyword: keyword, limit: 100)
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.25)) {
                searchState.setResult(
                    loadedResult,
                    usesSplitChannelBrowser: browsePresentation.usesSplitLayout,
                    previousSplitContext: searchState.splitContext
                )
            }
        }
        logger.debug(
            "screen_snapshot_load_complete",
            metadata: [
                "keyword": keywordPreview,
                "source": searchState.result.source.label,
                "videos": String(searchState.result.videos.count),
                "error": searchState.result.errorMessage == nil ? "none" : "present",
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                "mode": presentationMode.rawValue,
            ]
        )
        applyDefaultSplitSelectionIfNeeded()
    }

    private func reloadResults(forceRefresh: Bool) async {
        let logger = AppConsoleLogger.youtubeSearch
        let keywordPreview = AppConsoleLogger.sanitizedKeyword(keyword)
        logger.info(
            "screen_refresh_start",
            metadata: [
                "keyword": keywordPreview,
                "force_refresh": forceRefresh ? "true" : "false",
                "current_videos": String(searchState.result.videos.count),
                "mode": presentationMode.rawValue,
            ]
        )
        if forceRefresh {
            searchState.beginRefresh()
            await Task.yield()
        }
        if forceRefresh {
            if case let .remoteSearch(refreshedResult) = await coordinator.performRefreshAction(.remoteSearch(keyword: keyword, limit: 100)) {
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.25)) {
                        searchState.setResult(
                            refreshedResult,
                            usesSplitChannelBrowser: browsePresentation.usesSplitLayout,
                            previousSplitContext: searchState.splitContext
                        )
                    }
                }
            }
        } else {
            let result = await coordinator.searchRemoteVideos(keyword: keyword, limit: 100, forceRefresh: false)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) {
                    searchState.setResult(
                        result,
                        usesSplitChannelBrowser: browsePresentation.usesSplitLayout,
                        previousSplitContext: searchState.splitContext
                    )
                }
            }
        }
        logger.notice(
            "screen_refresh_complete",
            metadata: [
                "keyword": keywordPreview,
                "source": searchState.result.source.label,
                "videos": String(searchState.result.videos.count),
                "fetched": searchState.result.fetchedAt == nil ? "false" : "true",
                "error": searchState.result.errorMessage == nil ? "none" : "present",
                "mode": presentationMode.rawValue,
            ]
        )
        applyDefaultSplitSelectionIfNeeded()
    }

    private func dismissChip() {
        guard searchState.presentationState.isChipVisible else { return }
        guard searchState.presentationState.chipMode != .refreshing else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            searchState.dismissChip()
        }
    }

    private func shouldDismissChip(for value: DragGesture.Value) -> Bool {
        value.translation.height < -8 || abs(value.translation.width) > 20
    }

    private func loadMoreIfNeeded() {
        searchState.loadMoreIfNeeded()
    }

    private func applyDefaultSplitSelectionIfNeeded() {
        guard browsePresentation.usesSplitLayout else { return }
        guard let context = searchState.presentationState.splitContext else {
            splitLoadTask?.cancel()
            searchState.clearSplitSelection()
            return
        }
        if searchState.splitContext == context { return }
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
        searchState.beginSplitSelection(context)
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
            withAnimation(.easeOut(duration: 0.25)) {
                searchState.finishSplitSelection(context, videos: loadedVideos)
            }
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
            withAnimation(.easeOut(duration: 0.25)) {
                searchState.finishSplitSelection(context, videos: loadedVideos)
            }
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
        searchState.loadSplitMoreIfNeeded()
    }

    private func recordRenderProbe(_ phase: String) {
        let metadata = [
            "phase": phase,
            "layout": browsePresentation.rawValue,
            "mode": presentationMode.rawValue,
            "videos": String(searchState.result.videos.count),
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
                result: searchState.result,
                visibleCount: searchState.presentationState.visibleCount,
                splitContext: $searchState.splitContext,
                splitVideos: $searchState.splitVideos,
                splitVisibleCount: $searchState.splitVisibleCount,
                isSplitLoading: searchState.isSplitLoading,
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
                openVideo: openVideo,
                path: $path,
                keyword: keyword,
                result: searchState.result,
                visibleCount: searchState.presentationState.visibleCount,
                allowsRefreshCommandBinding: presentationMode == .visible,
                onRefresh: { await reloadResults(forceRefresh: true) },
                onDismissChip: dismissChip,
                onLoadMore: loadMoreIfNeeded,
                normalizedChannelTitle: normalizedChannelTitle(for:)
            )
        }
    }
}
