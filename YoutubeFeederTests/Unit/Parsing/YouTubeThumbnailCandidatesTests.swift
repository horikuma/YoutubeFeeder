import XCTest
@testable import YoutubeFeeder

final class YouTubeThumbnailCandidatesTests: LoggedTestCase {
    func testCandidateURLsFollowHighestToLowestOrder() {
        let urls = YouTubeThumbnailCandidates.urls(for: "video-1").map(\.absoluteString)

        XCTAssertEqual(
            urls,
            [
                "https://i.ytimg.com/vi/video-1/maxresdefault.jpg",
                "https://i.ytimg.com/vi/video-1/sddefault.jpg",
                "https://i.ytimg.com/vi/video-1/hqdefault.jpg",
                "https://i.ytimg.com/vi/video-1/mqdefault.jpg",
                "https://i.ytimg.com/vi/video-1/default.jpg"
            ]
        )
    }

    func testFilterPlayableVideosUsesVideoIDBasedThumbnailInsteadOfResponseThumbnail() {
        let item = VideoListResponse.Item(
            id: "video-1",
            snippet: VideoListResponse.Snippet(
                publishedAt: ISO8601DateFormatter().date(from: "2026-03-11T12:34:56Z"),
                channelID: "UC111",
                channelTitle: "Example Channel",
                title: "Example Title",
                liveBroadcastContent: "none",
                thumbnails: VideoThumbnails(
                    defaultThumbnail: VideoThumbnail(url: URL(string: "https://example.com/default.jpg")),
                    medium: VideoThumbnail(url: URL(string: "https://example.com/medium.jpg")),
                    high: VideoThumbnail(url: URL(string: "https://example.com/high.jpg"))
                )
            ),
            contentDetails: VideoListResponse.ContentDetails(duration: "PT1M30S"),
            statistics: VideoListResponse.Statistics(viewCount: "100"),
            liveStreamingDetails: nil
        )

        let videos = YouTubeSearchService.filterPlayableVideos([item])

        XCTAssertEqual(videos.count, 1)
        XCTAssertEqual(videos.first?.thumbnailURL?.absoluteString, "https://i.ytimg.com/vi/video-1/maxresdefault.jpg")
    }
}
