import XCTest
import Foundation

class UITestCaseSupport: XCTestCase {
    override class func setUp() {
        super.setUp()
        UITestMetricsBootstrap.registerIfNeeded()
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func launchApp(extraEnvironment: [String: String] = [:], useMockData: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["YOUTUBEFEEDER_UI_TEST_MODE"] = "1"
        app.launchEnvironment["YOUTUBEFEEDER_UI_TEST_USE_MOCK"] = useMockData ? "1" : "0"
        for (key, value) in extraEnvironment {
            app.launchEnvironment[key] = value
        }
        app.launch()
        return app
    }

    func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func waitForHomeScreen(in app: XCUIApplication, timeout: TimeInterval = 5) {
        XCTAssertTrue(element("screen.home", in: app).waitForExistence(timeout: timeout))
    }
}
