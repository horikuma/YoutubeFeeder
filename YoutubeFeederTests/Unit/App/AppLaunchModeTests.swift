import XCTest
@testable import YoutubeFeeder

final class AppLaunchModeTests: LoggedTestCase {
    func testAutoRefreshOnLaunchDefaultsToEnabledInNormalMode() {
        XCTAssertTrue(AppLaunchMode.autoRefreshOnLaunch(mode: .normal, uiTestAutoRefreshEnabled: false))
    }

    func testAutoRefreshOnLaunchIsDisabledInUITestModeUntilExplicitlyEnabled() {
        XCTAssertFalse(AppLaunchMode.autoRefreshOnLaunch(mode: .uiTestMock, uiTestAutoRefreshEnabled: false))
        XCTAssertFalse(AppLaunchMode.autoRefreshOnLaunch(mode: .uiTestLive, uiTestAutoRefreshEnabled: false))
    }

    func testAutoRefreshOnLaunchCanBeEnabledInUITestMode() {
        XCTAssertTrue(AppLaunchMode.autoRefreshOnLaunch(mode: .uiTestMock, uiTestAutoRefreshEnabled: true))
        XCTAssertTrue(AppLaunchMode.autoRefreshOnLaunch(mode: .uiTestLive, uiTestAutoRefreshEnabled: true))
    }

    func testAllowsBackgroundRefreshOnlyInNormalMode() {
        XCTAssertTrue(AppLaunchMode.normal.allowsBackgroundRefresh)
        XCTAssertFalse(AppLaunchMode.uiTestMock.allowsBackgroundRefresh)
        XCTAssertFalse(AppLaunchMode.uiTestLive.allowsBackgroundRefresh)
    }
}
