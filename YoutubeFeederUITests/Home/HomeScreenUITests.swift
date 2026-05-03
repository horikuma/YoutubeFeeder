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

    func testPlaylistTileShowsContinuousPlayMenuOnMacRightClick() throws {
        let app = launchApp()

        waitForHomeScreen(in: app)
        element("channel.tile.UC_TEST_ALPHA", in: app).click()
        app.buttons["プレイリスト一覧"].click()

        let playlistTile = element("playlist.tile.UC_TEST_ALPHA-playlist-001", in: app)
        XCTAssertTrue(playlistTile.waitForExistence(timeout: 5))

        openContextMenu(on: playlistTile)

        XCTAssertTrue(waitForActionMenuItem("連続再生", in: app))
    }
}
