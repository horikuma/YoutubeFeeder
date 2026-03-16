import XCTest

final class BrowseScreenUITests: UITestCaseSupport {
    func testAllVideosScreenScrollsWithMockData() throws {
        let app = launchApp(extraEnvironment: ["HELLOWORLD_UI_TEST_INITIAL_ROUTE": "allVideos"])

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
        let app = launchApp(extraEnvironment: ["HELLOWORLD_UI_TEST_INITIAL_ROUTE": "allVideos"])

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
        let app = launchApp(extraEnvironment: ["HELLOWORLD_UI_TEST_INITIAL_ROUTE": "channelList"])

        XCTAssertTrue(element("screen.title", in: app).waitForExistence(timeout: 5))

        let tipsTile = element("channel.tipsTile", in: app)
        XCTAssertTrue(tipsTile.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["channel.tipsTile"].exists)
    }

    func testRemoteSearchRefreshUpdatesResultsWithDummyTrigger() throws {
        let app = launchApp(extraEnvironment: ["HELLOWORLD_UI_TEST_INITIAL_ROUTE": "channelSearchResults"])

        let firstVideoMarker = element("test.remoteSearch.firstVideoID", in: app)
        XCTAssertTrue(firstVideoMarker.waitForExistence(timeout: 5))
        XCTAssertNotEqual(firstVideoMarker.label, "remote-refresh-001")

        let refreshTrigger = element("test.remoteSearch.refresh", in: app)
        XCTAssertTrue(refreshTrigger.waitForExistence(timeout: 3))
        refreshTrigger.tap()

        XCTAssertTrue(eventually(timeout: 5) {
            firstVideoMarker.label == "remote-refresh-001"
        })
        XCTAssertTrue(element("video.tile.remote-refresh-001", in: app).waitForExistence(timeout: 3))
    }

    func testRemoteSearchChipStaysVisibleUntilUserInteraction() throws {
        let app = launchApp(extraEnvironment: ["HELLOWORLD_UI_TEST_INITIAL_ROUTE": "channelSearchResults"])

        let refreshTrigger = element("test.remoteSearch.refresh", in: app)
        XCTAssertTrue(refreshTrigger.waitForExistence(timeout: 3))
        refreshTrigger.tap()

        let chip = element("search.resultChip", in: app)
        XCTAssertTrue(chip.waitForExistence(timeout: 3))
        sleep(5)
        XCTAssertTrue(chip.exists)

        app.scrollViews.firstMatch.swipeUp()
        XCTAssertTrue(eventually(timeout: 3) {
            !chip.exists
        })
    }

    func testRemoteSearchTapShowsChannelTitleAndTriggersAutomaticRefresh() throws {
        let app = launchApp(extraEnvironment: ["HELLOWORLD_UI_TEST_INITIAL_ROUTE": "channelSearchResults"])

        let refreshTrigger = element("test.remoteSearch.refresh", in: app)
        XCTAssertTrue(refreshTrigger.waitForExistence(timeout: 3))
        refreshTrigger.tap()

        let remoteTile = element("video.tile.remote-refresh-001", in: app)
        XCTAssertTrue(remoteTile.waitForExistence(timeout: 3))
        remoteTile.tap()

        let title = element("screen.title", in: app)
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        XCTAssertEqual(title.label, "Refresh Channel")

        let refreshMarker = element("test.channelRefreshTarget", in: app)
        XCTAssertTrue(refreshMarker.waitForExistence(timeout: 3))
        XCTAssertTrue(eventually(timeout: 3) {
            refreshMarker.label == "UC_REMOTE_REFRESH"
        })
    }
}
