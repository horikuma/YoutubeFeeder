import XCTest

final class HelloWorldUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testStartupUsesMockDataAndReportsTiming() throws {
        let app = launchApp()

        XCTAssertTrue(element("screen.home", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("progress.stage.フィード更新確認", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("progress.stage.更新チャンネル取得", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("progress.stage.サムネイル取得", in: app).waitForExistence(timeout: 3))

        let timeline = try timelinePayload(in: app)
        XCTAssertLessThan(try offset(for: "bootstrapLoaded", in: timeline), 2000)
        XCTAssertLessThan(try offset(for: "maintenanceShown", in: timeline), 2500)
    }

    func testHomeRefreshUsesMockPathWithoutNetwork() throws {
        let app = launchApp()

        XCTAssertTrue(element("screen.home", in: app).waitForExistence(timeout: 5))
        let refreshTrigger = element("test.refresh", in: app)
        XCTAssertTrue(refreshTrigger.waitForExistence(timeout: 3))
        refreshTrigger.tap()

        XCTAssertTrue(eventually(timeout: 5) {
            self.element("test.manualRefreshCount", in: app).value as? String == "1"
        })
    }

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

        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3))
        let countMarker = element("test.channelVideoCount", in: app)
        XCTAssertTrue(countMarker.waitForExistence(timeout: 3))
        XCTAssertTrue(eventually(timeout: 5) {
            guard let value = countMarker.value as? String, let count = Int(value) else {
                return false
            }
            return count > 0
        })
        scrollView.swipeUp()
        scrollView.swipeUp()

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

    private func eventually(timeout: TimeInterval, pollInterval: TimeInterval = 0.2, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
        }
        return condition()
    }
}
