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
}
