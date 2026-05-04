import XCTest

final class HomeScreenUITests: UITestCaseSupport {
    func testAppLaunchesWithoutCrashing() throws {
        let app = launchApp()

        XCTAssertEqual(app.state, .runningForeground)
    }

    func testHomeScreenAppearsAfterLaunch() throws {
        let app = launchApp()

        waitForHomeScreen(in: app)
        XCTAssertTrue(element("screen.home", in: app).exists)
    }

    func testChannelListRouteTriggerOpensChannelList() throws {
        let app = launchApp()

        waitForHomeScreen(in: app)

        app.buttons["test.channelList.route"].click()

        XCTAssertTrue(element("screen.title", in: app).waitForExistence(timeout: 5))
    }
}
