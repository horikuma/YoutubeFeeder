import XCTest
import Foundation

class UITestCaseSupport: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func launchApp(extraEnvironment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["HELLOWORLD_UI_TEST_MODE"] = "1"
        for (key, value) in extraEnvironment {
            app.launchEnvironment[key] = value
        }
        app.launch()
        return app
    }

    func timelinePayload(in app: XCUIApplication) throws -> [String: [String: String]] {
        let marker = element("diagnostics.timeline", in: app)
        XCTAssertTrue(marker.waitForExistence(timeout: 5))

        let rawValue = (marker.value as? String) ?? "{}"
        let data = try XCTUnwrap(rawValue.data(using: .utf8))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: [String: String]]
        return try XCTUnwrap(json)
    }

    func timelinePayloadIfAvailable(in app: XCUIApplication) -> [String: [String: String]]? {
        let marker = element("diagnostics.timeline", in: app)
        guard marker.exists || marker.waitForExistence(timeout: 0.2) else {
            return nil
        }

        guard let rawValue = (marker.value as? String)?.data(using: .utf8) else {
            return nil
        }

        return try? JSONSerialization.jsonObject(with: rawValue) as? [String: [String: String]]
    }

    func offset(for key: String, in payload: [String: [String: String]]) throws -> Int {
        let value = try XCTUnwrap(payload[key]?["offset_ms"])
        return try XCTUnwrap(Int(value))
    }

    func startupMetrics(from payload: [String: [String: String]]) throws -> [String: Int] {
        let appLaunchToSplash = try offset(for: "splashShown", in: payload)
        let appLaunchToBootstrap = try offset(for: "bootstrapLoaded", in: payload)
        let appLaunchToHome = try offset(for: "maintenanceShown", in: payload)
        let appLaunchToMaintenanceEnter = try offset(for: "maintenanceEntered", in: payload)

        return [
            "app_launch_to_splash_ms": appLaunchToSplash,
            "app_launch_to_bootstrap_ms": appLaunchToBootstrap,
            "app_launch_to_home_ms": appLaunchToHome,
            "app_launch_to_maintenance_enter_ms": appLaunchToMaintenanceEnter,
            "splash_to_home_ms": appLaunchToHome - appLaunchToSplash,
            "bootstrap_to_home_ms": appLaunchToHome - appLaunchToBootstrap,
        ]
    }

    func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func waitForHomeScreen(in app: XCUIApplication, timeout: TimeInterval = 5) {
        XCTAssertTrue(element("screen.home", in: app).waitForExistence(timeout: timeout))
    }

    func swipeBack(in app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5))
        start.press(forDuration: 0.01, thenDragTo: end)
    }

    func eventually(timeout: TimeInterval, pollInterval: TimeInterval = 0.2, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
        }
        return condition()
    }

    func writeJSONIfRequested(_ object: Any, environmentKey: String) throws {
        guard let outputPath = ProcessInfo.processInfo.environment[environmentKey], !outputPath.isEmpty else {
            return
        }

        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: outputPath), options: [.atomic])
    }
}
