import XCTest
@testable import YoutubeFeeder

final class ChannelBrowseLogicTests: LoggedTestCase {
    func testSetItemsClearsSelectionWhenChannelDisappears() {
        var state = ChannelBrowseLogic()
        state.items = [
            makeItem(channelID: "UC001", title: "Alpha"),
            makeItem(channelID: "UC002", title: "Beta")
        ]
        state.selectChannel("UC002")

        state.setItems([makeItem(channelID: "UC001", title: "Alpha")])

        XCTAssertNil(state.selectedChannelID)
    }

    func testSetItemsInvalidatesSelectedChannelVideosWhenSelectedItemChanges() {
        var state = ChannelBrowseLogic()
        let initialVideo = makeVideo(id: "video-1", channelID: "UC001", channelTitle: "Alpha")
        state.setItems([
            makeItem(channelID: "UC001", title: "Alpha", latestVideo: initialVideo, cachedVideoCount: 1)
        ])
        state.selectChannel("UC001")
        state.videosByChannelID["UC001"] = [initialVideo]

        state.setItems([
            makeItem(
                channelID: "UC001",
                title: "Alpha",
                latestVideo: makeVideo(id: "video-2", channelID: "UC001", channelTitle: "Alpha"),
                cachedVideoCount: 2
            )
        ])

        XCTAssertNil(state.videosByChannelID["UC001"])
        XCTAssertEqual(state.selectedChannelRefreshSource, "channel_list_update")
    }

    func testSetItemsKeepsSelectedChannelVideosWhenSelectedItemIsUnchanged() {
        var state = ChannelBrowseLogic()
        let initialVideo = makeVideo(id: "video-1", channelID: "UC001", channelTitle: "Alpha")
        let item = makeItem(channelID: "UC001", title: "Alpha", latestVideo: initialVideo, cachedVideoCount: 1)
        state.setItems([item])
        state.selectChannel("UC001")
        state.videosByChannelID["UC001"] = [initialVideo]

        state.setItems([item])

        XCTAssertEqual(state.videosByChannelID["UC001"], [initialVideo])
        XCTAssertNil(state.selectedChannelRefreshSource)
    }

    func testApplyDefaultSelectionUsesFirstAvailableChannel() {
        var state = ChannelBrowseLogic()
        state.setItems([
            makeItem(channelID: "UC001", title: "Alpha"),
            makeItem(channelID: "UC002", title: "Beta")
        ])

        XCTAssertEqual(state.applyDefaultSelectionIfNeeded(), "UC001")
        XCTAssertEqual(state.selectedChannelID, "UC001")
        XCTAssertEqual(state.selectedTitle(), "Alpha")
    }

    func testRemovalFeedbackAndPendingRemovalCanBeManagedIndependently() {
        var state = ChannelBrowseLogic()
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

    func testLoadingLifecycleStoresVideosOnceAndTracksLoadingState() {
        var state = ChannelBrowseLogic()
        let videos = [makeVideo(id: "video-1", channelID: "UC001", channelTitle: "Alpha")]

        XCTAssertTrue(state.beginLoadingVideos(for: "UC001"))
        XCTAssertFalse(state.beginLoadingVideos(for: "UC001"))
        state.finishLoadingVideos(videos, for: "UC001")

        XCTAssertEqual(state.videosByChannelID["UC001"], videos)
        XCTAssertFalse(state.beginLoadingVideos(for: "UC001"))
        XCTAssertEqual(state.videosForSelectedChannel(), [])
    }

    func testRefreshSelectedChannelVideosReplacesSelectedChannelVideos() {
        var state = ChannelBrowseLogic()
        state.setItems([makeItem(channelID: "UC001", title: "Alpha")])
        state.selectChannel("UC001")

        state.refreshSelectedChannelVideos([
            makeVideo(id: "video-1", channelID: "UC001", channelTitle: "Alpha")
        ])

        XCTAssertEqual(state.videosForSelectedChannel().count, 1)
        XCTAssertEqual(state.selectedTitle(), "Alpha")
    }

    private func makeItem(
        channelID: String,
        title: String,
        latestVideo: CachedVideo? = nil,
        cachedVideoCount: Int = 0
    ) -> ChannelBrowseItem {
        ChannelBrowseItem(
            id: channelID,
            channelID: channelID,
            channelTitle: title,
            latestPublishedAt: nil,
            registeredAt: nil,
            latestVideo: latestVideo,
            cachedVideoCount: cachedVideoCount
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
