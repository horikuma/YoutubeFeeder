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

    private lazy var splitSelectionCoordinator = RemoteSearchSplitSelectionController(
        owner: self,
        coordinator: coordinator,
        presentationMode: presentationMode
    )

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

    func onAppear() {
        StartupDiagnostics.shared.mark("keywordSearchShown")
        RuntimeDiagnostics.shared.record(
            "remote_search_screen_shown",
            detail: "YouTube検索画面を表示",
            metadata: [
                "keyword": keyword,
                "layout": browsePresentation.rawValue,
                "mode": presentationMode.rawValue
            ]
        )
        AppConsoleLogger.youtubeSearch.info(
            "screen_appear",
            metadata: [
                "keyword": AppConsoleLogger.sanitizedKeyword(keyword),
                "mode": presentationMode.rawValue
            ]
        )
    }

    func onDisappear() {
        splitSelectionCoordinator.cancel()
        AppConsoleLogger.youtubeSearch.info(
            "screen_disappear",
            metadata: [
                "keyword": AppConsoleLogger.sanitizedKeyword(keyword),
                "videos": String(result.videos.count),
                "refreshing": presentationState.isRefreshingChip ? "true" : "false",
                "mode": presentationMode.rawValue
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
                "mode": presentationMode.rawValue
            ]
        )
        let loadedResult = await coordinator.loadSnapshot(keyword: keyword, limit: 100)
        applyResult(loadedResult)
        logger.info(
            "screen_snapshot_load_complete",
            metadata: [
                "keyword": keywordPreview,
                "source": result.source.label,
                "videos": String(result.videos.count),
                "error": result.errorMessage == nil ? "none" : "present",
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                "mode": presentationMode.rawValue
            ]
        )
        splitSelectionCoordinator.applyDefaultSplitSelectionIfNeeded()
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
                "mode": presentationMode.rawValue
            ]
        )
        if forceRefresh {
            beginRefresh()
            await Task.yield()
        }
        if forceRefresh {
            if case let .remoteSearch(refreshedResult) = await coordinator.refresh(intent: .remoteSearch(keyword: keyword, limit: 100)) {
                applyResult(refreshedResult)
            }
        } else {
            let refreshedResult = await coordinator.search(keyword: keyword, limit: 100, forceRefresh: false)
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
                "mode": presentationMode.rawValue
            ]
        )
        splitSelectionCoordinator.applyDefaultSplitSelectionIfNeeded()
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
        splitSelectionCoordinator.selectSplitChannel(context)
    }

    func refreshSplitSelection() async {
        await splitSelectionCoordinator.refreshSplitSelection()
    }

    func loadSplitMoreIfNeeded() {
        splitSelectionCoordinator.loadSplitMoreIfNeeded()
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
    }
}
