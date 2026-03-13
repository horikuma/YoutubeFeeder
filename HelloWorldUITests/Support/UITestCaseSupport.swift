import XCTest

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

    func offset(for key: String, in payload: [String: [String: String]]) throws -> Int {
        let value = try XCTUnwrap(payload[key]?["offset_ms"])
        return try XCTUnwrap(Int(value))
    }

    func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
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
}
