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

    func testAppendSelectedChannelVideosDeduplicatesExistingItemsAndPreservesOrder() {
        var state = ChannelBrowseLogic()
        state.setItems([makeItem(channelID: "UC001", title: "Alpha")])
        state.selectChannel("UC001")
        state.videosByChannelID["UC001"] = [makeVideo(id: "video-1", channelID: "UC001", channelTitle: "Alpha")]

        state.appendSelectedChannelVideos([
            makeVideo(id: "video-1", channelID: "UC001", channelTitle: "Alpha"),
            makeVideo(id: "video-2", channelID: "UC001", channelTitle: "Alpha")
        ])

        XCTAssertEqual(state.videosByChannelID["UC001"]?.map(\.id), ["video-1", "video-2"])
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

    func testDisplayModeDefaultsToVideosAndCanSwitchPerChannel() {
        var state = ChannelBrowseLogic()

        XCTAssertEqual(state.displayMode(for: "UC001"), .videos)

        state.setDisplayMode(.playlists, for: "UC001")
        XCTAssertEqual(state.displayMode(for: "UC001"), .playlists)

        state.setDisplayMode(.videos, for: "UC001")
        XCTAssertEqual(state.displayMode(for: "UC001"), .videos)
    }

    func testRefreshPlaylistsTracksSelectionAndPlaylistVideos() {
        var state = ChannelBrowseLogic()

        state.refreshPlaylists(
            [
                makePlaylist(id: "PL001", title: "Playlist 1"),
                makePlaylist(id: "PL002", title: "Playlist 2")
            ],
            for: "UC001"
        )
        state.selectPlaylist("PL002", for: "UC001")
        state.refreshPlaylistVideos(
            makePlaylistPage(
                playlistID: "PL002",
                videos: [
                    makePlaylistVideo(id: "video-1", title: "Video 1"),
                    makePlaylistVideo(id: "video-2", title: "Video 2")
                ],
                nextPageToken: "NEXT"
            )
        )

        XCTAssertTrue(state.hasLoadedPlaylists(for: "UC001"))
        XCTAssertEqual(state.selectedPlaylistID(for: "UC001"), "PL002")
        XCTAssertEqual(state.selectedPlaylistTitle(for: "UC001"), "Playlist 2")
        XCTAssertEqual(state.selectedPlaylistVideos(for: "UC001").map(\.id), ["video-1", "video-2"])
        XCTAssertEqual(state.playlistVideosPage(for: "PL002")?.nextPageToken, "NEXT")
    }

    func testSelectedPlaylistVideosDefaultToNewestFirstAndCanSwitchToOldestFirst() {
        var state = ChannelBrowseLogic()
        state.setItems([makeItem(channelID: "UC001", title: "Alpha")])
        state.selectChannel("UC001")
        state.refreshPlaylists([makePlaylist(id: "PL001", title: "Playlist 1")], for: "UC001")
        state.selectPlaylist("PL001", for: "UC001")
        state.refreshPlaylistVideos(
            makePlaylistPage(
                playlistID: "PL001",
                videos: [
                    makePlaylistVideo(
                        id: "video-old",
                        title: "Old",
                        publishedAt: Date(timeIntervalSince1970: 1_742_000_000)
                    ),
                    makePlaylistVideo(
                        id: "video-new",
                        title: "New",
                        publishedAt: Date(timeIntervalSince1970: 1_742_100_000)
                    )
                ]
            )
        )

        XCTAssertEqual(state.selectedPlaylistVideos(for: "UC001").map(\.id), ["video-new", "video-old"])

        state.setPlaylistVideoSortOrder(.oldestFirst, for: "PL001")

        XCTAssertEqual(state.selectedPlaylistVideos(for: "UC001").map(\.id), ["video-old", "video-new"])
    }

    func testSetItemsClearsPlaylistStateWhenSelectedChannelDisappears() {
        var state = ChannelBrowseLogic()
        state.setItems([makeItem(channelID: "UC001", title: "Alpha")])
        state.selectChannel("UC001")
        state.setDisplayMode(.playlists, for: "UC001")
        state.refreshPlaylists([makePlaylist(id: "PL001", title: "Playlist 1")], for: "UC001")
        state.selectPlaylist("PL001", for: "UC001")
        state.refreshPlaylistVideos(makePlaylistPage(playlistID: "PL001", videos: [makePlaylistVideo(id: "video-1", title: "Video 1")]))

        state.setItems([makeItem(channelID: "UC002", title: "Beta")])

        XCTAssertNil(state.selectedChannelID)
        XCTAssertEqual(state.displayMode(for: "UC001"), .videos)
        XCTAssertFalse(state.hasLoadedPlaylists(for: "UC001"))
        XCTAssertNil(state.selectedPlaylistID(for: "UC001"))
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

    private func makePlaylist(id: String, title: String) -> PlaylistBrowseItem {
        PlaylistBrowseItem(
            id: id,
            playlistID: id,
            channelID: "UC001",
            channelTitle: "Alpha",
            title: title,
            description: nil,
            publishedAt: nil,
            itemCount: nil,
            thumbnailURL: nil
        )
    }

    private func makePlaylistVideo(
        id: String,
        title: String,
        publishedAt: Date = Date(timeIntervalSince1970: 1_742_000_000)
    ) -> PlaylistBrowseVideo {
        PlaylistBrowseVideo(
            id: id,
            channelID: "UC001",
            channelTitle: "Alpha",
            title: title,
            publishedAt: publishedAt,
            videoURL: nil,
            thumbnailURL: nil,
            durationSeconds: nil,
            viewCount: nil
        )
    }

    private func makePlaylistPage(
        playlistID: String,
        videos: [PlaylistBrowseVideo],
        nextPageToken: String? = nil
    ) -> PlaylistBrowseVideosPage {
        PlaylistBrowseVideosPage(
            playlistID: playlistID,
            videos: videos,
            totalCount: videos.count,
            fetchedAt: Date(timeIntervalSince1970: 1_742_000_000),
            nextPageToken: nextPageToken
        )
    }
}
