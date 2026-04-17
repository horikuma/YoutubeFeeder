import XCTest
@testable import YoutubeFeeder

final class RemoteSearchLogicTests: LoggedTestCase {
    func testDefaultsStartEmptyAndIdle() {
        let state = RemoteSearchLogic()

        XCTAssertEqual(state.result.keyword, "")
        XCTAssertTrue(state.result.videos.isEmpty)
        XCTAssertEqual(state.result.totalCount, 0)
        XCTAssertEqual(state.presentationState.visibleCount, 20)
        XCTAssertEqual(state.presentationState.chipMode, .hidden)
        XCTAssertNil(state.presentationState.splitContext)
        XCTAssertNil(state.splitContext)
        XCTAssertTrue(state.splitVideos.isEmpty)
        XCTAssertEqual(state.splitVisibleCount, 20)
        XCTAssertFalse(state.isSplitLoading)
    }

    func testSetResultAndSplitSelectionLifecycle() {
        var state = RemoteSearchLogic()
        let context = makeContext(channelID: "UC001", title: "Alpha")
        let videos = [
            makeVideo(id: "video-1", channelID: "UC001", channelTitle: "Alpha"),
            makeVideo(id: "video-2", channelID: "UC001", channelTitle: "Alpha")
        ]
        let result = VideoSearchResult(
            keyword: "swift",
            videos: videos,
            totalCount: videos.count,
            fetchedAt: Date(timeIntervalSince1970: 1_742_000_000)
        )

        state.setResult(result, usesSplitChannelBrowser: true, previousSplitContext: context)

        XCTAssertEqual(state.result, result)
        XCTAssertEqual(state.presentationState.chipMode, .summary)
        XCTAssertEqual(state.presentationState.splitContext, context)
        XCTAssertEqual(state.splitContext, context)

        state.beginSplitSelection(context)

        XCTAssertEqual(state.splitContext, context)
        XCTAssertTrue(state.splitVideos.isEmpty)
        XCTAssertEqual(state.splitVisibleCount, 20)
        XCTAssertTrue(state.isSplitLoading)
        XCTAssertEqual(state.presentationState.splitContext, context)

        state.finishSplitSelection(context, videos: videos)

        XCTAssertEqual(state.splitVideos, videos)
        XCTAssertEqual(state.splitVisibleCount, 2)
        XCTAssertFalse(state.isSplitLoading)

        state.loadSplitMoreIfNeeded()

        XCTAssertEqual(state.splitVisibleCount, 2)

        state.clearSplitSelection()

        XCTAssertNil(state.splitContext)
        XCTAssertTrue(state.splitVideos.isEmpty)
        XCTAssertEqual(state.splitVisibleCount, 20)
        XCTAssertFalse(state.isSplitLoading)
        XCTAssertNil(state.presentationState.splitContext)
    }

    private func makeContext(channelID: String, title: String) -> ChannelVideosRouteContext {
        ChannelVideosRouteContext(
            channelID: channelID,
            preferredChannelTitle: title,
            selectedVideoID: nil,
            prefersAutomaticRefresh: true,
            routeSource: .remoteSearch
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
