import XCTest

final class HomeScreenUITests: UITestCaseSupport {
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
            self.element("test.manualRefreshCount", in: app).label == "1"
        })
    }
}
