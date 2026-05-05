import XCTest
@testable import YoutubeFeeder

final class FeedCacheMaintenanceShortsTests: LoggedTestCase {

    func testLoadVideosMasksUnderFourMinuteVideosAsShorts() async throws {
        try await withTemporaryFeedCacheBaseDirectory { fileManager in
            let now = ISO8601DateFormatter().date(from: "2026-03-15T03:00:00Z")!
            let database = FeedCacheSQLiteDatabase.shared(fileManager: fileManager)
            database.replaceFeedSnapshot(makeShortsSnapshot(now: now))

            let store = FeedCacheStore()
            let visibleVideos = await store.loadVideos(
                query: VideoQuery(limit: .max, channelID: "UC111", keyword: nil, sortOrder: .publishedDescending, excludeShorts: true)
            )

            XCTAssertEqual(visibleVideos.map(\.id), ["video-visible"])
        }
    }
}

private func makeShortsSnapshot(now: Date) -> FeedCacheSnapshot {
    FeedCacheSnapshot(
        savedAt: now,
        channels: [makeShortsChannelState(now: now)],
        videos: [
            makeShortVideo(
                .init(
                    id: "video-short-duration",
                    title: "short by duration",
                    publishedAt: now,
                    videoURL: URL(string: "https://example.com/watch?v=1"),
                    fetchedAt: now,
                    searchableText: "short by duration",
                    durationSeconds: 239,
                    viewCount: 101
                )
            ),
            makeShortVideo(
                .init(
                    id: "video-shorts-url",
                    title: "normal title",
                    publishedAt: now.addingTimeInterval(-60),
                    videoURL: URL(string: "https://www.youtube.com/shorts/abc123"),
                    fetchedAt: now,
                    searchableText: "normal title",
                    durationSeconds: nil,
                    viewCount: 102
                )
            ),
            makeShortVideo(
                .init(
                    id: "video-visible",
                    title: "visible video",
                    publishedAt: now.addingTimeInterval(-120),
                    videoURL: URL(string: "https://example.com/watch?v=3"),
                    fetchedAt: now,
                    searchableText: "visible video",
                    durationSeconds: 240,
                    viewCount: 103
                )
            )
        ]
    )
}

private func makeShortsChannelState(now: Date) -> CachedChannelState {
    CachedChannelState(
        channelID: "UC111",
        channelTitle: "one",
        lastAttemptAt: now,
        lastCheckedAt: now,
        lastSuccessAt: now,
        latestPublishedAt: now,
        cachedVideoCount: 3,
        lastError: nil,
        etag: nil,
        lastModified: nil
    )
}

private struct ShortVideoSpec {
    let id: String
    let title: String
    let publishedAt: Date
    let videoURL: URL?
    let fetchedAt: Date
    let searchableText: String
    let durationSeconds: Int?
    let viewCount: Int
}

private func makeShortVideo(_ spec: ShortVideoSpec) -> CachedVideo {
    CachedVideo(
        id: spec.id,
        channelID: "UC111",
        channelTitle: "one",
        title: spec.title,
        publishedAt: spec.publishedAt,
        videoURL: spec.videoURL,
        thumbnailRemoteURL: nil,
        thumbnailLocalFilename: nil,
        fetchedAt: spec.fetchedAt,
        searchableText: spec.searchableText,
        durationSeconds: spec.durationSeconds,
        viewCount: spec.viewCount
    )
}
