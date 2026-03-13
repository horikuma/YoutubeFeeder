import XCTest
@testable import HelloWorld

final class ChannelResourceTests: XCTestCase {
    func testParseChannelIDsTrimsWhitespaceAndSkipsEmptyLines() {
        let contents = """
          UC111

        UC222
          UC333

        """

        XCTAssertEqual(ChannelResource.parseChannelIDs(contents), ["UC111", "UC222", "UC333"])
    }
}
