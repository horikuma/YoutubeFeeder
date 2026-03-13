import XCTest

final class BrowseScreenUITests: UITestCaseSupport {
    func testAllVideosScreenScrollsWithMockData() throws {
        let app = launchApp()

        XCTAssertTrue(element("nav.videos", in: app).waitForExistence(timeout: 5))
        element("nav.videos", in: app).tap()
        XCTAssertTrue(element("screen.title", in: app).waitForExistence(timeout: 3))

        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3))
        let firstTile = element("video.tile.alpha-12", in: app)
        XCTAssertTrue(firstTile.waitForExistence(timeout: 5))
        XCTAssertTrue(firstTile.isHittable)
        scrollView.swipeUp()
        scrollView.swipeUp()
        XCTAssertFalse(firstTile.isHittable)
    }

    func testChannelVideosScreenScrollsWithMockData() throws {
        let app = launchApp()

        XCTAssertTrue(element("nav.channels", in: app).waitForExistence(timeout: 5))
        element("nav.channels", in: app).tap()
        XCTAssertTrue(element("channel.tile.UC_TEST_ALPHA", in: app).waitForExistence(timeout: 3))
        element("channel.tile.UC_TEST_ALPHA", in: app).tap()

        XCTAssertTrue(app.staticTexts["このチャンネルの動画を新しい順に最大50件表示"].waitForExistence(timeout: 5))
        let loadMarker = element("screen.channelVideos.loaded", in: app)
        XCTAssertTrue(loadMarker.waitForExistence(timeout: 5))
        XCTAssertTrue(eventually(timeout: 5) {
            loadMarker.label == "alpha-12"
        })
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3))
        let firstTile = element("video.tile.alpha-12", in: app)
        XCTAssertTrue(firstTile.waitForExistence(timeout: 5))
        XCTAssertTrue(firstTile.isHittable)
        scrollView.swipeUp()
        scrollView.swipeUp()
        XCTAssertFalse(firstTile.isHittable)

        let timeline = try timelinePayload(in: app)
        XCTAssertLessThan(try offset(for: "channelListShown", in: timeline), 3500)
        XCTAssertLessThan(try offset(for: "channelVideosShown", in: timeline), 7000)
    }
}
