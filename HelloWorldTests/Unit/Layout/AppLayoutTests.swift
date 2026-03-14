import SwiftUI
import XCTest
@testable import HelloWorld

final class AppLayoutTests: XCTestCase {
    func testCompactWidthNeverUsesSplitChannelBrowser() {
        let layout = AppLayout.current(
            size: CGSize(width: 844, height: 390),
            horizontalSizeClass: .compact
        )

        XCTAssertFalse(layout.usesRegularWidth)
        XCTAssertFalse(layout.usesSplitChannelBrowser)
        XCTAssertFalse(layout.isPad)
    }

    func testRegularWidthLandscapeUsesSplitChannelBrowser() {
        let layout = AppLayout.current(
            size: CGSize(width: 1366, height: 1024),
            horizontalSizeClass: .regular
        )

        XCTAssertTrue(layout.usesRegularWidth)
        XCTAssertTrue(layout.usesSplitChannelBrowser)
        XCTAssertTrue(layout.isPad)
    }

    func testRegularWidthPortraitKeepsSingleColumnChannelBrowser() {
        let layout = AppLayout.current(
            size: CGSize(width: 1024, height: 1366),
            horizontalSizeClass: .regular
        )

        XCTAssertTrue(layout.usesRegularWidth)
        XCTAssertFalse(layout.usesSplitChannelBrowser)
        XCTAssertTrue(layout.isPad)
    }
}
