import CoreGraphics
import XCTest
@testable import YoutubeFeeder

final class BackSwipePolicyTests: LoggedTestCase {
    func testAcceptsHorizontalSwipeFromLeftEdge() {
        XCTAssertTrue(
            BackSwipePolicy.shouldNavigateBack(
                startX: 24,
                translation: CGSize(width: 120, height: 10)
            )
        )
    }

    func testRejectsVerticalOrFarRightSwipe() {
        XCTAssertFalse(
            BackSwipePolicy.shouldNavigateBack(
                startX: 200,
                translation: CGSize(width: 120, height: 5)
            )
        )
        XCTAssertFalse(
            BackSwipePolicy.shouldNavigateBack(
                startX: 24,
                translation: CGSize(width: 40, height: 120)
            )
        )
    }
}
