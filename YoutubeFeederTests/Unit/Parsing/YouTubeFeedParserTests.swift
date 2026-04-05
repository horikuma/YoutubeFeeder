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
}
