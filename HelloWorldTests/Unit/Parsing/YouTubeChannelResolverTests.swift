import XCTest
@testable import HelloWorld

final class YouTubeChannelResolverTests: XCTestCase {
    func testDirectChannelIDReturnsAsIs() {
        XCTAssertEqual(
            YouTubeChannelInput.directChannelID(from: "UCabcdefghijklmnopqrstuv"),
            "UCabcdefghijklmnopqrstuv"
        )
    }

    func testChannelURLReturnsEmbeddedChannelID() {
        XCTAssertEqual(
            YouTubeChannelInput.directChannelID(from: "https://www.youtube.com/channel/UCabcdefghijklmnopqrstuv"),
            "UCabcdefghijklmnopqrstuv"
        )
    }

    func testLookupURLTreatsPlainTextAsHandle() throws {
        let url = try YouTubeChannelInput.lookupURL(from: "nogizaka")
        XCTAssertEqual(url.absoluteString, "https://www.youtube.com/@nogizaka")
    }

    func testExtractChannelIDReadsExternalIDFromHTML() {
        let html = #"<script>{"externalId":"UCabcdefghijklmnopqrstuv"}</script>"#
        XCTAssertEqual(
            YouTubeChannelInput.extractChannelID(from: html),
            "UCabcdefghijklmnopqrstuv"
        )
    }
}
