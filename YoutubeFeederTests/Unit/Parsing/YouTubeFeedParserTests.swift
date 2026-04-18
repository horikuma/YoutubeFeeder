import XCTest
@testable import YoutubeFeeder

final class YouTubeFeedParserTests: LoggedTestCase {
    func testUploadsPlaylistIDConvertsChannelID() {
        XCTAssertEqual(
            YouTubeFeedService.uploadsPlaylistID(for: "UCabcdefghijk"),
            "UULFabcdefghijk"
        )
        XCTAssertEqual(
            YouTubeFeedService.uploadsPlaylistID(for: "PL12345"),
            "PL12345"
        )
    }

    func testYouTubeFeedParserParsesEntryMetadata() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns:yt="http://www.youtube.com/xml/schemas/2015" xmlns:media="http://search.yahoo.com/mrss/">
          <entry>
            <yt:videoId>video-1</yt:videoId>
            <title>Example Title</title>
            <published>2026-03-11T12:34:56+00:00</published>
            <author><name>Example Channel</name></author>
            <link rel="alternate" href="https://www.youtube.com/watch?v=video-1" />
            <media:group>
              <media:thumbnail url="https://i.ytimg.com/vi/video-1/hqdefault.jpg" />
            </media:group>
          </entry>
        </feed>
        """

        let videos = YouTubeFeedParser().parse(data: Data(xml.utf8))

        XCTAssertEqual(videos.count, 1)
        XCTAssertEqual(videos.first?.id, "video-1")
        XCTAssertEqual(videos.first?.title, "Example Title")
        XCTAssertEqual(videos.first?.channelTitle, "Example Channel")
        XCTAssertEqual(videos.first?.videoURL?.absoluteString, "https://www.youtube.com/watch?v=video-1")
        XCTAssertEqual(videos.first?.thumbnailURL?.absoluteString, "https://i.ytimg.com/vi/video-1/maxresdefault.jpg")
    }

    func testFeedResponseDiagnosticsReportsFeedWithoutEntries() {
        let data = Data(#"<?xml version="1.0"?><feed></feed>"#.utf8)

        let metadata = YouTubeFeedResponseDiagnostics.parseMetadata(
            channelID: "UC_EMPTY",
            httpResponse: Self.response(statusCode: 200),
            data: data,
            parsedVideos: []
        )

        XCTAssertEqual(metadata["diagnosis"], "feed_without_entries")
        XCTAssertEqual(metadata["raw_entry_tags"], "0")
        XCTAssertEqual(metadata["raw_video_id_tags"], "0")
        XCTAssertEqual(metadata["parsed_videos"], "0")
    }

    func testFeedResponseDiagnosticsReportsHTMLResponse() {
        let data = Data(#"<!doctype html><html><body>not found</body></html>"#.utf8)

        let metadata = YouTubeFeedResponseDiagnostics.parseMetadata(
            channelID: "UC_HTML",
            httpResponse: Self.response(statusCode: 200),
            data: data,
            parsedVideos: []
        )

        XCTAssertEqual(metadata["diagnosis"], "html_response")
        XCTAssertEqual(metadata["raw_entry_tags"], "0")
        XCTAssertEqual(metadata["parsed_videos"], "0")
    }

    func testFeedResponseDiagnosticsReportsParsedVideosPresent() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns:yt="http://www.youtube.com/xml/schemas/2015">
          <entry>
            <yt:videoId>video-1</yt:videoId>
            <title>Example Title</title>
            <published>2026-03-11T12:34:56+00:00</published>
          </entry>
        </feed>
        """
        let data = Data(xml.utf8)
        let videos = YouTubeFeedParser().parse(data: data)

        let metadata = YouTubeFeedResponseDiagnostics.parseMetadata(
            channelID: "UC_VALID",
            httpResponse: Self.response(statusCode: 200),
            data: data,
            parsedVideos: videos
        )

        XCTAssertEqual(metadata["diagnosis"], "parsed_videos_present")
        XCTAssertEqual(metadata["raw_entry_tags"], "1")
        XCTAssertEqual(metadata["raw_video_id_tags"], "1")
        XCTAssertEqual(metadata["parsed_videos"], "1")
        XCTAssertEqual(metadata["first_video_id"], "video-1")
    }

    private static func response(statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://www.youtube.com/feeds/videos.xml")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }
}
