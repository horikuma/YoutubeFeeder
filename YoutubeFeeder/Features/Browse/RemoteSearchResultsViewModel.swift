import Combine
import SwiftUI

@MainActor
final class RemoteSearchResultsViewModel: ObservableObject {
    let keyword: String
    let coordinator: FeedCacheCoordinator
    let browsePresentation: BasicGUIBrowsePresentation
    let presentationMode: RemoteSearchPresentationMode

    @Published var result: VideoSearchResult
    @Published var presentationState: RemoteSearchPresentationState
    @Published var splitContext: ChannelVideosRouteContext?
    @Published var splitVideos: [CachedVideo]
    @Published var splitVisibleCount: Int
    @Published var isSplitLoading: Bool

    private var splitLoadTask: Task<Void, Never>?

    init(
        keyword: String,
        coordinator: FeedCacheCoordinator,
        browsePresentation: BasicGUIBrowsePresentation,
        presentationMode: RemoteSearchPresentationMode
    ) {
        self.keyword = keyword
        self.coordinator = coordinator
        self.browsePresentation = browsePresentation
        self.presentationMode = presentationMode
        let initialResult = VideoSearchResult(keyword: keyword, videos: [], totalCount: 0)
        self.result = initialResult
        self.presentationState = RemoteSearchPresentationState(
            visibleCount: 20,
            chipMode: .hidden,
            splitContext: nil
        )
        self.splitContext = nil
        self.splitVideos = []
        self.splitVisibleCount = 20
        self.isSplitLoading = false
    }

    deinit {
        splitLoadTask?.cancel()
    }

    func onAppear() {
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

    func onDisappear() {
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

    func loadSnapshot() async {
        let logger = AppConsoleLogger.youtubeSearch
        let keywordPreview = AppConsoleLogger.sanitizedKeyword(keyword)
        let startedAt = Date()
        logger.info(
            "screen_snapshot_load_start",
            metadata: [
                "keyword": keywordPreview,
                "limit": "100",
                "mode": presentationMode.rawValue,
            ]
        )
        let loadedResult = await coordinator.loadRemoteSearchSnapshot(keyword: keyword, limit: 100)
        applyResult(loadedResult)
        logger.info(
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
        applyDefaultSplitSelectionIfNeeded()
    }

    func reloadResults(forceRefresh: Bool) async {
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
            beginRefresh()
            await Task.yield()
        }
        if forceRefresh {
            if case let .remoteSearch(refreshedResult) = await coordinator.performRefreshAction(.remoteSearch(keyword: keyword, limit: 100)) {
                applyResult(refreshedResult)
            }
        } else {
            let refreshedResult = await coordinator.searchRemoteVideos(keyword: keyword, limit: 100, forceRefresh: false)
            applyResult(refreshedResult)
        }
        logger.info(
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
        applyDefaultSplitSelectionIfNeeded()
    }

    func clearRemoteSearchHistory() async {
        await coordinator.clearRemoteSearchHistory(keyword: keyword)
        await loadSnapshot()
    }

    func dismissChip() {
        guard presentationState.isChipVisible else { return }
        guard presentationState.chipMode != .refreshing else { return }
        presentationState.dismissChip()
    }

    func shouldDismissChip(for value: DragGesture.Value) -> Bool {
        value.translation.height < -8 || abs(value.translation.width) > 20
    }

    func loadMoreIfNeeded() {
        presentationState.loadMoreIfNeeded(totalVideoCount: result.videos.count)
    }

    func selectSplitChannel(_ context: ChannelVideosRouteContext) {
        splitLoadTask?.cancel()
        beginSplitSelection(context)
        splitLoadTask = Task { [weak self] in
            await self?.performImmediateSplitSelection(context)
        }
    }

    func refreshSplitSelection() async {
        guard let splitContext else { return }
        if case let .channelVideos(reloadedVideos) = await coordinator.performRefreshAction(.channel(splitContext)) {
            splitVideos = reloadedVideos
            splitVisibleCount = min(20, splitVideos.count)
        }
    }

    func loadSplitMoreIfNeeded() {
        guard splitVisibleCount < splitVideos.count else { return }
        splitVisibleCount = min(splitVisibleCount + 20, splitVideos.count)
    }

    func normalizedChannelTitle(for video: CachedVideo) -> String? {
        video.channelTitle.isEmpty ? nil : video.channelTitle
    }

    private func beginRefresh() {
        presentationState.beginRefresh()
    }

    private func applyResult(_ loadedResult: VideoSearchResult) {
        result = loadedResult
        presentationState = RemoteSearchPresentationState.build(
            result: loadedResult,
            usesSplitChannelBrowser: browsePresentation.usesSplitLayout,
            previousSplitContext: splitContext
        )
        splitContext = presentationState.splitContext
        if !browsePresentation.usesSplitLayout {
            clearSplitSelection()
        }
    }

    private func beginSplitSelection(_ context: ChannelVideosRouteContext) {
        splitContext = context
        splitVideos = []
        splitVisibleCount = 20
        isSplitLoading = true
        presentationState.splitContext = context
    }

    private func clearSplitSelection() {
        splitContext = nil
        splitVideos = []
        splitVisibleCount = 20
        isSplitLoading = false
        presentationState.splitContext = nil
    }

    private func finishSplitSelection(_ context: ChannelVideosRouteContext, videos: [CachedVideo]) {
        guard splitContext == context else { return }
        splitVideos = videos
        splitVisibleCount = min(20, videos.count)
        isSplitLoading = false
    }

    private func applyDefaultSplitSelectionIfNeeded() {
        guard browsePresentation.usesSplitLayout else { return }
        guard let context = presentationState.splitContext else {
            splitLoadTask?.cancel()
            clearSplitSelection()
            return
        }
        if splitContext == context { return }
        scheduleDeferredSplitSelection(context)
    }

    private func scheduleDeferredSplitSelection(_ context: ChannelVideosRouteContext) {
        splitLoadTask?.cancel()
        beginSplitSelection(context)
        let scheduledAt = Date()
        recordDeferredSplitSelectionScheduled(context)

        splitLoadTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard let self, !Task.isCancelled else { return }
            await self.performDeferredSplitSelection(context, scheduledAt: scheduledAt)
        }
    }

    private func performImmediateSplitSelection(_ context: ChannelVideosRouteContext) async {
        let startedAt = Date()
        AppConsoleLogger.remoteSearchSplitLoad.info(
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
        finishSplitSelection(context, videos: loadedVideos)

        AppConsoleLogger.remoteSearchSplitLoad.info(
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
        finishSplitSelection(context, videos: loadedVideos)
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
        AppConsoleLogger.appLifecycle.info(
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
}
