import XCTest
@testable import YoutubeFeeder

final class VideoListLogicTests: LoggedTestCase {
    func testDefaultsStartEmptyAndIdle() {
        let state = VideoListLogic()

        XCTAssertTrue(state.videos.isEmpty)
        XCTAssertFalse(state.isAutomaticRefreshInProgress)
        XCTAssertNil(state.pendingChannelRemoval)
        XCTAssertNil(state.removalFeedback)
    }

    func testAutomaticRefreshLifecycleTracksLoadingStateAndVideos() {
        var state = VideoListLogic()
        let videos = [makeVideo(id: "video-1", channelID: "UC001", channelTitle: "Alpha")]

        state.beginAutomaticRefresh()

        XCTAssertTrue(state.isAutomaticRefreshInProgress)

        state.setVideos(videos)

        XCTAssertEqual(state.videos, videos)
        XCTAssertFalse(state.isAutomaticRefreshInProgress)

        state.beginAutomaticRefresh()
        state.finishAutomaticRefresh(videos)

        XCTAssertEqual(state.videos, videos)
        XCTAssertFalse(state.isAutomaticRefreshInProgress)
    }

    func testAppendVideosDeduplicatesExistingItemsAndPreservesOrder() {
        var state = VideoListLogic()
        let existing = makeVideo(id: "video-1", channelID: "UC001", channelTitle: "Alpha")
        let appended = [
            makeVideo(id: "video-1", channelID: "UC001", channelTitle: "Alpha"),
            makeVideo(id: "video-2", channelID: "UC001", channelTitle: "Alpha")
        ]

        state.setVideos([existing])
        state.appendVideos(appended)

        XCTAssertEqual(state.videos.map(\.id), ["video-1", "video-2"])
    }

    func testRemovalFeedbackAndPendingRemovalCanBeManagedIndependently() {
        var state = VideoListLogic()
        let item = makeItem(channelID: "UC001", title: "Alpha")
        let feedback = ChannelRemovalFeedback(
            channelID: item.channelID,
            channelTitle: item.channelTitle,
            removedVideoCount: 3,
            removedThumbnailCount: 2
        )

        state.requestRemoval(for: item)
        state.applyRemovalFeedback(feedback)
        state.clearPendingRemoval()

        XCTAssertNil(state.pendingChannelRemoval)
        XCTAssertEqual(state.removalFeedback, feedback)
        XCTAssertEqual(state.removalFeedback?.title, "チャンネルを削除しました")
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
