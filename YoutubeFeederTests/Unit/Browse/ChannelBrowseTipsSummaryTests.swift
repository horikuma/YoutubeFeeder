import XCTest
@testable import YoutubeFeeder

final class ChannelBrowseTipsSummaryTests: LoggedTestCase {
    func testBuildSummarizesChannelCountAndSort() {
        let items = [
            makeItem(channelID: "UC001", title: "Alpha"),
            makeItem(channelID: "UC002", title: "Beta")
        ]

        let summary = ChannelBrowseTipsSummary.build(
            items: items,
            sortDescriptor: ChannelBrowseSortDescriptor(metric: .registrationDate, direction: .ascending)
        )

        XCTAssertEqual(summary.countText, "2件")
        XCTAssertEqual(summary.sortText, "チャンネル登録日時 ↑")
        XCTAssertEqual(summary.primaryHint, "タップで動画一覧")
        XCTAssertEqual(summary.secondaryHint, "クリックでメニュー")
    }

    func testBuildHandlesEmptyList() {
        let summary = ChannelBrowseTipsSummary.build(
            items: [],
            sortDescriptor: .default
        )

        XCTAssertEqual(summary.countText, "0件")
        XCTAssertEqual(summary.sortText, "動画投稿日時 ↓")
    }

    func testDesktopInteractionPlatformUsesDesktopHints() {
        XCTAssertTrue(AppInteractionPlatform.desktop.usesPrimaryClickForMenus)
        XCTAssertTrue(AppInteractionPlatform.desktop.usesMenuCommandForRefresh)
        XCTAssertEqual(AppInteractionPlatform.desktop.menuInteractionHint, "クリックでメニュー")
    }

    func testTouchInteractionPlatformUsesTouchHints() {
        XCTAssertFalse(AppInteractionPlatform.touch.usesPrimaryClickForMenus)
        XCTAssertFalse(AppInteractionPlatform.touch.usesMenuCommandForRefresh)
        XCTAssertEqual(AppInteractionPlatform.touch.menuInteractionHint, "長押しで削除")
    }

    func testRemoteSearchPresentationBuildShowsChipWhenFetchedAtExists() {
        let fetchedAt = Date(timeIntervalSince1970: 1_742_000_000)
        let result = VideoSearchResult(
            keyword: "swift",
            videos: [],
            totalCount: 0,
            source: .remoteAPI,
            fetchedAt: fetchedAt
        )

        let state = RemoteSearchPresentationState.build(
            result: result,
            usesSplitChannelBrowser: false,
            previousSplitContext: nil
        )

        XCTAssertEqual(state.visibleCount, 20)
        XCTAssertTrue(state.isChipVisible)
        XCTAssertEqual(state.chipMode, .summary)
        XCTAssertNil(state.splitContext)
    }

    func testRemoteSearchPresentationBuildPreservesExistingSplitSelectionWhenChannelStillExists() {
        let previousContext = ChannelVideosRouteContext(
            channelID: "UC_KEEP",
            preferredChannelTitle: "Keep Channel",
            selectedVideoID: "keep-1",
            prefersAutomaticRefresh: true,
            routeSource: .remoteSearch
        )
        let result = VideoSearchResult(
            keyword: "swift",
            videos: [
                makeVideo(id: "keep-2", channelID: "UC_KEEP", channelTitle: "Keep Channel"),
                makeVideo(id: "other-1", channelID: "UC_OTHER", channelTitle: "Other Channel")
            ],
            totalCount: 2,
            source: .remoteAPI,
            fetchedAt: Date(timeIntervalSince1970: 1_742_000_000)
        )

        let state = RemoteSearchPresentationState.build(
            result: result,
            usesSplitChannelBrowser: true,
            previousSplitContext: previousContext
        )

        XCTAssertEqual(state.splitContext, previousContext)
    }

    func testRemoteSearchPresentationBuildFallsBackToFirstVideoForSplitSelection() {
        let result = VideoSearchResult(
            keyword: "swift",
            videos: [
                makeVideo(id: "first-1", channelID: "UC_FIRST", channelTitle: "First Channel"),
                makeVideo(id: "second-1", channelID: "UC_SECOND", channelTitle: "Second Channel")
            ],
            totalCount: 2,
            source: .remoteAPI,
            fetchedAt: Date(timeIntervalSince1970: 1_742_000_000)
        )

        let state = RemoteSearchPresentationState.build(
            result: result,
            usesSplitChannelBrowser: true,
            previousSplitContext: ChannelVideosRouteContext(channelID: "UC_MISSING")
        )

        XCTAssertEqual(
            state.splitContext,
            ChannelVideosRouteContext(
                channelID: "UC_FIRST",
                preferredChannelTitle: "First Channel",
                selectedVideoID: "first-1",
                prefersAutomaticRefresh: true,
                routeSource: .remoteSearch
            )
        )
    }

    func testRemoteSearchPresentationDismissChipAndLoadMore() {
        let result = VideoSearchResult(
            keyword: "swift",
            videos: (0..<21).map { index in
                makeVideo(
                    id: "video-\(index)",
                    channelID: "UC_\(index)",
                    channelTitle: "Channel \(index)"
                )
            },
            totalCount: 21,
            source: .remoteAPI,
            fetchedAt: Date(timeIntervalSince1970: 1_742_000_000)
        )
        var state = RemoteSearchPresentationState.build(
            result: result,
            usesSplitChannelBrowser: false,
            previousSplitContext: nil
        )

        state.dismissChip()
        state.loadMoreIfNeeded(totalVideoCount: result.videos.count)

        XCTAssertFalse(state.isChipVisible)
        XCTAssertEqual(state.chipMode, .hidden)
        XCTAssertEqual(state.visibleCount, 21)
    }

    func testRemoteSearchPresentationBeginRefreshShowsRefreshingChip() {
        let result = VideoSearchResult(
            keyword: "swift",
            videos: [],
            totalCount: 0,
            source: .remoteCache,
            fetchedAt: Date(timeIntervalSince1970: 1_742_000_000)
        )
        var state = RemoteSearchPresentationState.build(
            result: result,
            usesSplitChannelBrowser: false,
            previousSplitContext: nil
        )

        state.beginRefresh()

        XCTAssertTrue(state.isChipVisible)
        XCTAssertTrue(state.isRefreshingChip)
        XCTAssertEqual(state.chipMode, .refreshing)
    }

    private func makeItem(channelID: String, title: String) -> ChannelBrowseItem {
        ChannelBrowseItem(
            id: channelID,
            channelID: channelID,
            channelTitle: title,
            latestPublishedAt: nil,
            registeredAt: nil,
            latestVideo: nil,
            cachedVideoCount: 0
        )
    }

    private func makeVideo(id: String, channelID: String, channelTitle: String) -> CachedVideo {
        CachedVideo(
            id: id,
            channelID: channelID,
            channelTitle: channelTitle,
            title: "Video \(id)",
            publishedAt: Date(timeIntervalSince1970: 1_742_000_000),
            videoURL: nil,
            thumbnailRemoteURL: nil,
            thumbnailLocalFilename: nil,
            fetchedAt: Date(timeIntervalSince1970: 1_742_000_000),
            searchableText: "search",
            durationSeconds: nil,
            viewCount: nil
        )
    }
}
