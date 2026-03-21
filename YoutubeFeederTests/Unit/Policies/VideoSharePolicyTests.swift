import XCTest
@testable import YoutubeFeeder

final class VideoSharePolicyTests: LoggedTestCase {
    func testShareURLReturnsVideoURLWhenAvailable() {
        let videoURL = URL(string: "https://www.youtube.com/watch?v=abc123")!
        let video = CachedVideo(
            id: "abc123",
            channelID: "UC_TEST",
            channelTitle: "Test Channel",
            title: "Test Video",
            publishedAt: Date(timeIntervalSince1970: 1_000),
            videoURL: videoURL,
            thumbnailRemoteURL: nil,
            thumbnailLocalFilename: nil,
            fetchedAt: Date(timeIntervalSince1970: 1_000),
            searchableText: "test",
            durationSeconds: 600,
            viewCount: 100
        )

        XCTAssertEqual(VideoSharePolicy.shareURL(for: video), videoURL)
    }

    func testShareURLReturnsNilWhenVideoURLIsMissing() {
        let video = CachedVideo(
            id: "abc123",
            channelID: "UC_TEST",
            channelTitle: "Test Channel",
            title: "Test Video",
            publishedAt: Date(timeIntervalSince1970: 1_000),
            videoURL: nil,
            thumbnailRemoteURL: nil,
            thumbnailLocalFilename: nil,
            fetchedAt: Date(timeIntervalSince1970: 1_000),
            searchableText: "test",
            durationSeconds: 600,
            viewCount: 100
        )

        XCTAssertNil(VideoSharePolicy.shareURL(for: video))
    }
}
