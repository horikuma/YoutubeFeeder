import XCTest
@testable import YoutubeFeeder

final class FeedCacheMaintenanceShortsTests: LoggedTestCase {

    func testLoadVideosMasksUnderFourMinuteVideosAsShorts() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        try await withFeedCacheBaseDirectory(temporaryRoot.appendingPathComponent("Cache", isDirectory: true)) {
            let now = ISO8601DateFormatter().date(from: "2026-03-15T03:00:00Z")!
            let snapshot = FeedCacheSnapshot(
                savedAt: now,
                channels: [
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
                ],
                videos: [
                    CachedVideo(
                        id: "video-short-duration",
                        channelID: "UC111",
                        channelTitle: "one",
                        title: "short by duration",
                        publishedAt: now,
                        videoURL: URL(string: "https://example.com/watch?v=1"),
                        thumbnailRemoteURL: nil,
                        thumbnailLocalFilename: nil,
                        fetchedAt: now,
                        searchableText: "short by duration",
                        durationSeconds: 239,
                        viewCount: 101
                    ),
                    CachedVideo(
                        id: "video-shorts-url",
                        channelID: "UC111",
                        channelTitle: "one",
                        title: "normal title",
                        publishedAt: now.addingTimeInterval(-60),
                        videoURL: URL(string: "https://www.youtube.com/shorts/abc123"),
                        thumbnailRemoteURL: nil,
                        thumbnailLocalFilename: nil,
                        fetchedAt: now,
                        searchableText: "normal title",
                        durationSeconds: nil,
                        viewCount: 102
                    ),
                    CachedVideo(
                        id: "video-visible",
                        channelID: "UC111",
                        channelTitle: "one",
                        title: "visible video",
                        publishedAt: now.addingTimeInterval(-120),
                        videoURL: URL(string: "https://example.com/watch?v=3"),
                        thumbnailRemoteURL: nil,
                        thumbnailLocalFilename: nil,
                        fetchedAt: now,
                        searchableText: "visible video",
                        durationSeconds: 240,
                        viewCount: 103
                    )
                ]
            )

            let database = FeedCacheSQLiteDatabase.shared(fileManager: fileManager)
            database.replaceFeedSnapshot(snapshot)

            let store = FeedCacheStore()
            let visibleVideos = await store.loadVideos(
                query: VideoQuery(limit: .max, channelID: "UC111", keyword: nil, sortOrder: .publishedDescending, excludeShorts: true)
            )

            XCTAssertEqual(visibleVideos.map(\.id), ["video-visible"])
        }
    }
}
