import XCTest

final class HelloWorldUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testStartupUsesMockDataAndReportsTiming() throws {
        let app = launchApp()

        XCTAssertTrue(element("screen.maintenance", in: app).waitForExistence(timeout: 5))

        let timeline = try timelinePayload(in: app)
        XCTAssertLessThan(try offset(for: "bootstrapLoaded", in: timeline), 2000)
        XCTAssertLessThan(try offset(for: "maintenanceShown", in: timeline), 2500)
    }

    func testAllVideosScreenScrollsWithMockData() throws {
        let app = launchApp()

        XCTAssertTrue(element("nav.videos", in: app).waitForExistence(timeout: 5))
        element("nav.videos", in: app).tap()
        XCTAssertTrue(element("screen.title", in: app).waitForExistence(timeout: 3))

        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3))
        XCTAssertFalse(element("video.tile.alpha-01", in: app).isHittable)
        scrollView.swipeUp()
        scrollView.swipeUp()
        XCTAssertTrue(element("video.tile.alpha-01", in: app).waitForExistence(timeout: 2))
    }

    func testChannelVideosScreenScrollsWithMockData() throws {
        let app = launchApp()

        XCTAssertTrue(element("nav.channels", in: app).waitForExistence(timeout: 5))
        element("nav.channels", in: app).tap()
        XCTAssertTrue(element("channel.tile.UC_TEST_ALPHA", in: app).waitForExistence(timeout: 3))
        element("channel.tile.UC_TEST_ALPHA", in: app).tap()

        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3))
        XCTAssertFalse(element("video.tile.alpha-01", in: app).isHittable)
        scrollView.swipeUp()
        scrollView.swipeUp()
        XCTAssertTrue(element("video.tile.alpha-01", in: app).waitForExistence(timeout: 2))

        let timeline = try timelinePayload(in: app)
        XCTAssertLessThan(try offset(for: "channelListShown", in: timeline), 3500)
        XCTAssertLessThan(try offset(for: "channelVideosShown", in: timeline), 5000)
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["HELLOWORLD_UI_TEST_MODE"] = "1"
        app.launch()
        return app
    }

    private func timelinePayload(in app: XCUIApplication) throws -> [String: [String: String]] {
        let marker = element("diagnostics.timeline", in: app)
        XCTAssertTrue(marker.waitForExistence(timeout: 5))

        let rawValue = (marker.value as? String) ?? "{}"
        let data = try XCTUnwrap(rawValue.data(using: .utf8))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: [String: String]]
        return try XCTUnwrap(json)
    }

    private func offset(for key: String, in payload: [String: [String: String]]) throws -> Int {
        let value = try XCTUnwrap(payload[key]?["offset_ms"])
        return try XCTUnwrap(Int(value))
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}
