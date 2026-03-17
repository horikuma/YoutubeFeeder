import XCTest
@testable import HelloWorld

final class AppFormattingTests: LoggedTestCase {
    func testVideoTileBadgeTextIncludesIndexDurationViewCountAndBucket() {
        XCTAssertEqual(
            AppFormatting.videoTileBadgeText(index: 0, durationSeconds: 83, viewCount: 45),
            "0 : 1m23s 45回 (M)"
        )
    }

    func testVideoTileBadgeTextHandlesMissingDurationAndViewCount() {
        XCTAssertEqual(
            AppFormatting.videoTileBadgeText(index: 7, durationSeconds: nil, viewCount: nil),
            "7 : --s --回 (--)"
        )
    }
}
