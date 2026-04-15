import XCTest

final class BrowseScreenUITests: UITestCaseSupport {
    func testAllVideosScreenScrollsWithMockData() throws {
        let app = launchApp(extraEnvironment: ["YOUTUBEFEEDER_UI_TEST_INITIAL_ROUTE": "allVideos"])

        XCTAssertTrue(element("screen.title", in: app).waitForExistence(timeout: 3))

        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3))
        let firstTile = element("video.tile.alpha-12", in: app)
        XCTAssertTrue(firstTile.waitForExistence(timeout: 5))
        XCTAssertTrue(firstTile.isHittable)
        scrollView.swipeUp()
        scrollView.swipeUp()
        XCTAssertFalse(firstTile.isHittable)

        let timeline = try timelinePayload(in: app)
        XCTAssertLessThan(try offset(for: "allVideosShown", in: timeline), 7000)
    }

    func testChannelVideosPullToRefreshRefreshesOnlySelectedChannel() throws {
        let app = launchApp(extraEnvironment: ["YOUTUBEFEEDER_UI_TEST_INITIAL_ROUTE": "allVideos"])

        XCTAssertTrue(element("video.tile.alpha-12", in: app).waitForExistence(timeout: 5))
        element("video.tile.alpha-12", in: app).tap()

        XCTAssertTrue(element("screen.channelVideos.loaded", in: app).waitForExistence(timeout: 3))
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3))

        let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        let end = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        start.press(forDuration: 0.05, thenDragTo: end)

        let marker = element("test.channelRefreshTarget", in: app)
        XCTAssertTrue(eventually(timeout: 3) {
            ((marker.label as String?) ?? "") == "UC_TEST_ALPHA"
        })
    }

    func testChannelListShowsNonInteractiveTipsTile() throws {
        let app = launchApp(extraEnvironment: ["YOUTUBEFEEDER_UI_TEST_INITIAL_ROUTE": "channelList"])

        XCTAssertTrue(element("screen.title", in: app).waitForExistence(timeout: 5))

        let tipsTile = element("channel.tipsTile", in: app)
        XCTAssertTrue(tipsTile.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["channel.tipsTile"].exists)
    }

    func testChannelListRefreshUpdatesVisibleListAndLogsReception() throws {
        let app = launchApp(
            extraEnvironment: [
                "YOUTUBEFEEDER_UI_TEST_INITIAL_ROUTE": "channelList",
                "YOUTUBEFEEDER_RUNTIME_LOGGING": "1"
            ]
        )

        XCTAssertTrue(element("screen.title", in: app).waitForExistence(timeout: 5))

        let initialEntries = try runtimePayload(in: app)
        XCTAssertFalse(initialEntries.contains { $0.event == "channel_list_received_update" })

        tapAsyncTrigger("test.refresh.command", in: app)

        XCTAssertTrue(eventually(timeout: 5) {
            guard let entries = self.runtimePayloadIfAvailable(in: app) else {
                return false
            }
            return entries.contains { $0.event == "refresh_ui_applied" }
                && entries.contains { $0.event == "channel_list_received_update" }
        })
    }

    func testRemoteSearchRefreshUpdatesResultsAndChipState() throws {
        let app = launchApp(extraEnvironment: ["YOUTUBEFEEDER_UI_TEST_INITIAL_ROUTE": "channelSearchResults"])

        let firstVideoMarker = element("test.remoteSearch.firstVideoID", in: app)
        XCTAssertTrue(firstVideoMarker.waitForExistence(timeout: 5))
        XCTAssertNotEqual(firstVideoMarker.label, "remote-refresh-001")

        let refreshPhase = element("search.refreshPhase", in: app)
        XCTAssertTrue(refreshPhase.waitForExistence(timeout: 5))

        tapAsyncTrigger("test.remoteSearch.refresh", in: app)

        XCTAssertTrue(eventually(timeout: 3) {
            refreshPhase.label == "refreshing"
        })
        XCTAssertTrue(eventually(timeout: 5) {
            firstVideoMarker.label == "remote-refresh-001"
        })
        XCTAssertTrue(eventually(timeout: 5) {
            refreshPhase.label == "summary"
        })
        XCTAssertTrue(element("video.tile.remote-refresh-001", in: app).waitForExistence(timeout: 3))
    }

    func testRemoteSearchChipDismissesOnUserInteraction() throws {
        let app = launchApp(extraEnvironment: ["YOUTUBEFEEDER_UI_TEST_INITIAL_ROUTE": "channelSearchResults"])

        tapAsyncTrigger("test.remoteSearch.refresh", in: app)

        let chip = element("search.resultChip", in: app)
        XCTAssertTrue(chip.waitForExistence(timeout: 3))
        app.scrollViews.firstMatch.swipeUp()
        XCTAssertTrue(eventually(timeout: 3) {
            !chip.exists
        })
    }

    func testRemoteSearchTapShowsChannelTitleAndTriggersAutomaticRefresh() throws {
        let app = launchApp(extraEnvironment: ["YOUTUBEFEEDER_UI_TEST_INITIAL_ROUTE": "channelSearchResults"])

        tapAsyncTrigger("test.remoteSearch.refresh", in: app)

        let remoteTile = element("video.tile.remote-refresh-001", in: app)
        XCTAssertTrue(remoteTile.waitForExistence(timeout: 3))
        remoteTile.tap()

        let title = element("screen.title", in: app)
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        XCTAssertEqual(title.label, "Refresh Channel")

        let autoRefreshState = element("channel.autoRefreshState", in: app)
        XCTAssertTrue(autoRefreshState.waitForExistence(timeout: 3))

        let refreshMarker = element("test.channelRefreshTarget", in: app)
        XCTAssertTrue(refreshMarker.waitForExistence(timeout: 3))
        XCTAssertTrue(eventually(timeout: 3) {
            refreshMarker.label == "UC_REMOTE_REFRESH"
        })
    }

    func testRemoteSearchLiveRefreshCompletesOnDevice() throws {
        let app = launchApp(
            extraEnvironment: ["YOUTUBEFEEDER_UI_TEST_INITIAL_ROUTE": "channelSearchResults"],
            useMockData: false
        )

        XCTAssertTrue(element("screen.title", in: app).waitForExistence(timeout: 8))

        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))

        let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        let end = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        start.press(forDuration: 0.05, thenDragTo: end)

        let failureTile = app.staticTexts["取得できません"]
        let anyVideoTile = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "video.tile.")
        ).firstMatch

        XCTAssertTrue(
            eventually(timeout: 20, pollInterval: 0.5) {
                failureTile.exists || anyVideoTile.exists
            }
        )
        XCTAssertFalse(failureTile.exists)
        XCTAssertTrue(anyVideoTile.exists)
    }
}
