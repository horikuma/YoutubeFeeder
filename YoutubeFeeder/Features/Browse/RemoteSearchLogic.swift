enum RemoteSearchChipMode: String, Hashable {
    case hidden
    case summary
    case refreshing
}

struct RemoteSearchPresentationState: Hashable {
    var visibleCount: Int
    var chipMode: RemoteSearchChipMode
    var splitContext: ChannelVideosRouteContext?

    var isChipVisible: Bool {
        chipMode != .hidden
    }

    var isRefreshingChip: Bool {
        chipMode == .refreshing
    }

    static func build(
        result: VideoSearchResult,
        usesSplitChannelBrowser: Bool,
        previousSplitContext: ChannelVideosRouteContext?
    ) -> Self {
        RemoteSearchPresentationState(
            visibleCount: min(20, max(result.videos.count, 20)),
            chipMode: result.fetchedAt != nil ? .summary : .hidden,
            splitContext: defaultSplitContext(
                result: result,
                usesSplitChannelBrowser: usesSplitChannelBrowser,
                previousSplitContext: previousSplitContext
            )
        )
    }

    mutating func dismissChip() {
        chipMode = .hidden
    }

    mutating func beginRefresh() {
        chipMode = .refreshing
    }

    mutating func loadMoreIfNeeded(totalVideoCount: Int) {
        guard visibleCount < totalVideoCount else { return }
        visibleCount = min(visibleCount + 20, totalVideoCount)
    }

    private static func defaultSplitContext(
        result: VideoSearchResult,
        usesSplitChannelBrowser: Bool,
        previousSplitContext: ChannelVideosRouteContext?
    ) -> ChannelVideosRouteContext? {
        guard usesSplitChannelBrowser else { return nil }
        if let previousSplitContext,
           result.videos.contains(where: { $0.channelID == previousSplitContext.channelID }) {
            return previousSplitContext
        }
        guard let firstVideo = result.videos.first else { return nil }
        return ChannelVideosRouteContext(
            channelID: firstVideo.channelID,
            preferredChannelTitle: normalizedChannelTitle(for: firstVideo),
            selectedVideoID: firstVideo.id,
            prefersAutomaticRefresh: true,
            routeSource: .remoteSearch
        )
    }

    private static func normalizedChannelTitle(for video: CachedVideo) -> String? {
        video.channelTitle.isEmpty ? nil : video.channelTitle
    }
}

struct RemoteSearchLogic: Hashable {
    var result: VideoSearchResult = VideoSearchResult(keyword: "", videos: [], totalCount: 0)
    var presentationState = RemoteSearchPresentationState(visibleCount: 20, chipMode: .hidden, splitContext: nil)
    var splitContext: ChannelVideosRouteContext?
    var splitVideos: [CachedVideo] = []
    var splitVisibleCount = 20
    var isSplitLoading = false

    mutating func setResult(
        _ result: VideoSearchResult,
        usesSplitChannelBrowser: Bool,
        previousSplitContext: ChannelVideosRouteContext?
    ) {
        self.result = result
        presentationState = RemoteSearchPresentationState.build(
            result: result,
            usesSplitChannelBrowser: usesSplitChannelBrowser,
            previousSplitContext: previousSplitContext
        )
        splitContext = presentationState.splitContext
        if !usesSplitChannelBrowser {
            clearSplitSelection()
        }
    }

    mutating func dismissChip() {
        presentationState.dismissChip()
    }

    mutating func beginRefresh() {
        presentationState.beginRefresh()
    }

    mutating func loadMoreIfNeeded() {
        presentationState.loadMoreIfNeeded(totalVideoCount: result.videos.count)
    }

    mutating func beginSplitSelection(_ context: ChannelVideosRouteContext) {
        splitContext = context
        splitVideos = []
        splitVisibleCount = 20
        isSplitLoading = true
        presentationState.splitContext = context
    }

    mutating func clearSplitSelection() {
        splitContext = nil
        splitVideos = []
        splitVisibleCount = 20
        isSplitLoading = false
        presentationState.splitContext = nil
    }

    mutating func finishSplitSelection(_ context: ChannelVideosRouteContext, videos: [CachedVideo]) {
        guard splitContext == context else { return }
        splitVideos = videos
        splitVisibleCount = min(20, videos.count)
        isSplitLoading = false
    }

    mutating func loadSplitMoreIfNeeded() {
        guard splitVisibleCount < splitVideos.count else { return }
        splitVisibleCount = min(splitVisibleCount + 20, splitVideos.count)
    }
}
