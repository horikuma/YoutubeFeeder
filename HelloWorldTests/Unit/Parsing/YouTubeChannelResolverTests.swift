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

    func testNormalizedVideoURLExtractsWatchURL() {
        XCTAssertEqual(
            YouTubeChannelInput.normalizedVideoURL(from: "https://www.youtube.com/watch?v=abc123XYZ"),
            URL(string: "https://www.youtube.com/watch?v=abc123XYZ")
        )
        XCTAssertEqual(
            YouTubeChannelInput.normalizedVideoURL(from: "https://youtu.be/abc123XYZ?t=30"),
            URL(string: "https://www.youtube.com/watch?v=abc123XYZ")
        )
        XCTAssertEqual(
            YouTubeChannelInput.normalizedVideoURL(from: "https://www.youtube.com/shorts/abc123XYZ"),
            URL(string: "https://www.youtube.com/watch?v=abc123XYZ")
        )
    }

    func testExtractChannelIDReadsExternalIDFromHTML() {
        let html = #"<script>{"externalId":"UCabcdefghijklmnopqrstuv"}</script>"#
        XCTAssertEqual(
            YouTubeChannelInput.extractChannelID(from: html),
            "UCabcdefghijklmnopqrstuv"
        )
    }

    func testExtractChannelIDReadsBrowseIDFromHTML() {
        let html = #"<script>{"browseId":"UCabcdefghijklmnopqrstuv"}</script>"#
        XCTAssertEqual(
            YouTubeChannelInput.extractChannelID(from: html),
            "UCabcdefghijklmnopqrstuv"
        )
    }
}
