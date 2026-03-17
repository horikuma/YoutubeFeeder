import XCTest
@testable import HelloWorld

final class ChannelVideosAutoRefreshPolicyTests: LoggedTestCase {
    func testRequiresRefreshWhenChannelHasNoCachedVideosYet() {
        XCTAssertTrue(
            ChannelVideosAutoRefreshPolicy.shouldRefresh(
                cachedChannelVideos: [],
                selectedVideoID: "video-1"
            )
        )
    }

    func testRequiresRefreshWhenSelectedVideoIsMissingFromChannelCache() {
        XCTAssertTrue(
            ChannelVideosAutoRefreshPolicy.shouldRefresh(
                cachedChannelVideos: [makeVideo(id: "video-1")],
                selectedVideoID: "video-2"
            )
        )
    }

    func testSkipsRefreshWhenSelectedVideoAlreadyExistsInChannelCache() {
        XCTAssertFalse(
            ChannelVideosAutoRefreshPolicy.shouldRefresh(
                cachedChannelVideos: [makeVideo(id: "video-1")],
                selectedVideoID: "video-1"
            )
        )
    }

    private func makeVideo(id: String) -> CachedVideo {
        CachedVideo(
            id: id,
            channelID: "UC_TEST",
            channelTitle: "Test Channel",
            title: "Video \(id)",
            publishedAt: Date(timeIntervalSince1970: 1_000),
            videoURL: nil,
            thumbnailRemoteURL: nil,
            thumbnailLocalFilename: nil,
            fetchedAt: Date(timeIntervalSince1970: 1_000),
            searchableText: "Video \(id)",
            durationSeconds: 1_200,
            viewCount: 100
        )
    }
}
