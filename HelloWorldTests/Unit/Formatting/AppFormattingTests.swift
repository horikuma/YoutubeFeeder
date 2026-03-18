import XCTest
@testable import HelloWorld

final class AppFormattingTests: LoggedTestCase {
    func testVideoTileBadgeTextRoundsDurationToMinutesAndFormatsViewCount() {
        XCTAssertEqual(
            AppFormatting.videoTileBadgeText(durationSeconds: 83, viewCount: 45),
            "1分 45回"
        )
    }

    func testVideoTileBadgeTextHandlesMissingDurationAndViewCount() {
        XCTAssertEqual(
            AppFormatting.videoTileBadgeText(durationSeconds: nil, viewCount: nil),
            "--分 --回"
        )
    }
}
