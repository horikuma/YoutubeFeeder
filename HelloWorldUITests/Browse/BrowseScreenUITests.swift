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

        let timeline = try timelinePayload(in: app)
        XCTAssertLessThan(try offset(for: "allVideosShown", in: timeline), 7000)
    }
}
