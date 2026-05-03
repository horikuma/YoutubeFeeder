import XCTest
import Foundation

class UITestCaseSupport: XCTestCase {
    private var launchedApps: [XCUIApplication] = []
    private var feedCacheBaseDirectories: [URL] = []

    override class func setUp() {
        super.setUp()
        UITestMetricsBootstrap.registerIfNeeded()
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        for app in launchedApps where app.state != .notRunning {
            app.terminate()
        }
        launchedApps.removeAll()

        for directory in feedCacheBaseDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        feedCacheBaseDirectories.removeAll()
    }

    func launchApp(extraEnvironment: [String: String] = [:], useMockData: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        let feedCacheBaseDirectory = makeIsolatedFeedCacheBaseDirectory()
        feedCacheBaseDirectories.append(feedCacheBaseDirectory)
        app.launchEnvironment["YOUTUBEFEEDER_UI_TEST_MODE"] = "1"
        app.launchEnvironment["YOUTUBEFEEDER_UI_TEST_USE_MOCK"] = useMockData ? "1" : "0"
        app.launchEnvironment["YOUTUBEFEEDER_FEEDCACHE_BASE_DIR"] = feedCacheBaseDirectory.path
        for (key, value) in extraEnvironment {
            guard key != "YOUTUBEFEEDER_FEEDCACHE_BASE_DIR" else { continue }
            app.launchEnvironment[key] = value
        }
        app.launch()
        launchedApps.append(app)
        return app
    }

    func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func waitForHomeScreen(in app: XCUIApplication, timeout: TimeInterval = 5) {
        XCTAssertTrue(element("screen.home", in: app).waitForExistence(timeout: timeout))
    }

    func openContextMenu(on element: XCUIElement) {
        element.rightClick()
    }

    func waitForActionMenuItem(_ title: String, in app: XCUIApplication, timeout: TimeInterval = 5) -> Bool {
        if app.menuItems[title].waitForExistence(timeout: timeout) {
            return true
        }
        return app.buttons[title].waitForExistence(timeout: timeout)
    }

    private func makeIsolatedFeedCacheBaseDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("YoutubeFeederUITests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("FeedCache", isDirectory: true)
    }
}
