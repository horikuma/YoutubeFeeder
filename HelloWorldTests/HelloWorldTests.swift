import CoreGraphics
import XCTest
@testable import HelloWorld

final class HelloWorldTests: XCTestCase {
    func testParseChannelIDsTrimsWhitespaceAndSkipsEmptyLines() {
        let contents = """
          UC111

        UC222
          UC333  
        
        """

        XCTAssertEqual(ChannelResource.parseChannelIDs(contents), ["UC111", "UC222", "UC333"])
    }

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

    func testBackSwipePolicyAcceptsHorizontalSwipeFromLeftEdge() {
        XCTAssertTrue(
            BackSwipePolicy.shouldNavigateBack(
                startX: 24,
                translation: CGSize(width: 120, height: 10)
            )
        )
    }

    func testBackSwipePolicyRejectsVerticalOrFarRightSwipe() {
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

    func testFeedOrderingPrioritizesLatestPublishedThenOldestChecked() {
        let now = Date(timeIntervalSince1970: 1_000)
        let channels = ["A", "B", "C"]
        let states: [String: CachedChannelState] = [
            "A": CachedChannelState(
                channelID: "A",
                channelTitle: nil,
                lastAttemptAt: nil,
                lastCheckedAt: now.addingTimeInterval(-50),
                lastSuccessAt: nil,
                latestPublishedAt: now.addingTimeInterval(-100),
                cachedVideoCount: 0,
                lastError: nil,
                etag: nil,
                lastModified: nil
            ),
            "B": CachedChannelState(
                channelID: "B",
                channelTitle: nil,
                lastAttemptAt: nil,
                lastCheckedAt: now.addingTimeInterval(-500),
                lastSuccessAt: nil,
                latestPublishedAt: now.addingTimeInterval(-100),
                cachedVideoCount: 0,
                lastError: nil,
                etag: nil,
                lastModified: nil
            ),
            "C": CachedChannelState(
                channelID: "C",
                channelTitle: nil,
                lastAttemptAt: nil,
                lastCheckedAt: now.addingTimeInterval(-10),
                lastSuccessAt: nil,
                latestPublishedAt: now.addingTimeInterval(-10),
                cachedVideoCount: 0,
                lastError: nil,
                etag: nil,
                lastModified: nil
            ),
        ]

        XCTAssertEqual(
            FeedOrdering.prioritizedChannelIDs(channels: channels, states: states),
            ["C", "B", "A"]
        )
    }

    func testFeedOrderingFreshnessClassifiesAge() {
        let now = Date(timeIntervalSince1970: 10_000)

        XCTAssertEqual(
            FeedOrdering.freshness(lastSuccessAt: now.addingTimeInterval(-30), now: now, freshnessInterval: 60),
            .fresh
        )
        XCTAssertEqual(
            FeedOrdering.freshness(lastSuccessAt: now.addingTimeInterval(-300), now: now, freshnessInterval: 60),
            .stale
        )
        XCTAssertEqual(
            FeedOrdering.freshness(lastSuccessAt: nil, now: now, freshnessInterval: 60),
            .neverFetched
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
        XCTAssertEqual(videos.first?.thumbnailURL?.absoluteString, "https://i.ytimg.com/vi/video-1/hqdefault.jpg")
    }
}
