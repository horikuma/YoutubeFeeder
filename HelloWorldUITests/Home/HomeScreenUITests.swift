import XCTest

final class HomeScreenUITests: UITestCaseSupport {
    func testStartupUsesMockDataAndReportsTiming() throws {
        let app = launchApp()

        XCTAssertTrue(element("screen.home", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("nav.channels", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("nav.videos", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("nav.channelRegistration", in: app).waitForExistence(timeout: 3))

        let timeline = try timelinePayload(in: app)
        XCTAssertLessThan(try offset(for: "bootstrapLoaded", in: timeline), 2000)
        XCTAssertLessThan(try offset(for: "maintenanceShown", in: timeline), 2500)
    }

    func testHomeRefreshUsesMockPathWithoutNetwork() throws {
        let app = launchApp(extraEnvironment: ["HELLOWORLD_UI_TEST_AUTO_REFRESH": "1"])

        XCTAssertTrue(element("screen.home", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(eventually(timeout: 5) {
            guard let timeline = try? self.timelinePayload(in: app) else {
                return false
            }
            return timeline["manualRefreshFinished"] != nil
        })
    }

    func testChannelRegistrationScreenShowsInputControls() throws {
        let app = launchApp()

        XCTAssertTrue(element("nav.channelRegistration", in: app).waitForExistence(timeout: 5))
        element("nav.channelRegistration", in: app).tap()

        XCTAssertTrue(element("channelRegistration.input", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("channelRegistration.submit", in: app).waitForExistence(timeout: 3))
    }

    func testChannelMenuShowsSortOptions() throws {
        let app = launchApp()

        XCTAssertTrue(element("nav.channels", in: app).waitForExistence(timeout: 5))
        element("nav.channels", in: app).tap()

        XCTAssertTrue(app.buttons["動画投稿日時 ↓"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["チャンネル登録日時 ↓"].waitForExistence(timeout: 3))
    }
}
