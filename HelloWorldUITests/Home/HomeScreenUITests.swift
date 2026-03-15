import XCTest

final class HomeScreenUITests: UITestCaseSupport {
    func testHomePrimaryNavigationAndFeedbackFlow() throws {
        let app = launchApp()

        waitForHomeScreen(in: app)
        XCTAssertTrue(element("nav.channels", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("nav.videos", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("nav.search", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("nav.channelRegistration", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("nav.registryTransfer", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["バックアップ"].waitForExistence(timeout: 3))

        let timeline = try timelinePayload(in: app)
        XCTAssertLessThan(try offset(for: "bootstrapLoaded", in: timeline), 2000)
        XCTAssertLessThan(try offset(for: "maintenanceShown", in: timeline), 2500)
        let startupMetrics = try startupMetrics(from: timeline)
        let payload = [
            "timeline": timeline,
            "startup_metrics": startupMetrics,
        ] as [String : Any]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
           let text = String(data: data, encoding: .utf8) {
            print("HELLOWORLD_STARTUP_METRICS \(text)")
        }
        try writeJSONIfRequested(
            payload,
            environmentKey: "HELLOWORLD_STARTUP_METRICS_OUTPUT"
        )
        element("nav.channels", in: app).tap()

        XCTAssertTrue(app.buttons["動画投稿日時 ↓"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["チャンネル登録日時 ↓"].waitForExistence(timeout: 3))
        app.buttons["動画投稿日時 ↓"].tap()

        XCTAssertTrue(element("screen.title", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["動画投稿日時が新しい順"].waitForExistence(timeout: 3))

        swipeBack(in: app)
        waitForHomeScreen(in: app, timeout: 3)

        element("nav.search", in: app).tap()
        XCTAssertTrue(app.staticTexts["「ゆっくり実況」に一致する動画を新しい順に20件表示"].waitForExistence(timeout: 3))
        XCTAssertTrue(element("search.resultChip", in: app).waitForExistence(timeout: 3))

        let searchScrollView = app.scrollViews.firstMatch
        XCTAssertTrue(searchScrollView.waitForExistence(timeout: 3))
        searchScrollView.swipeUp()
        XCTAssertTrue(eventually(timeout: 3) {
            !self.element("search.resultChip", in: app).exists
        })

        swipeBack(in: app)
        waitForHomeScreen(in: app, timeout: 3)

        element("nav.channelRegistration", in: app).tap()
        XCTAssertTrue(element("channelRegistration.input", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("channelRegistration.submit", in: app).waitForExistence(timeout: 3))
    }

    func testHomeRefreshUsesMockPathWithoutNetwork() throws {
        let app = launchApp(extraEnvironment: ["HELLOWORLD_UI_TEST_AUTO_REFRESH": "1"])

        waitForHomeScreen(in: app)
        XCTAssertTrue(eventually(timeout: 5) {
            guard let timeline = self.timelinePayloadIfAvailable(in: app) else {
                return false
            }
            return timeline["manualRefreshFinished"] != nil
        })
    }
}
