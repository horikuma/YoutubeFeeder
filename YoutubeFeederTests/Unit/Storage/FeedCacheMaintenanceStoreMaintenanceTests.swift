import XCTest
@testable import YoutubeFeeder

final class FeedCacheMaintenanceStoreMaintenanceTests: LoggedTestCase {

    func testCacheThumbnailForCachedVideoUsesVideoIDCandidatesAndPersistsFilename() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        try await withFeedCacheBaseDirectory(temporaryRoot.appendingPathComponent("Cache", isDirectory: true)) {
            let thumbnailsDirectory = FeedCachePaths.thumbnailsDirectory(fileManager: fileManager)
            try fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)

            let now = ISO8601DateFormatter().date(from: "2026-03-15T03:00:00Z")!
            let snapshot = FeedCacheSnapshot(
                savedAt: now,
                channels: [],
                videos: [
                    CachedVideo(
                        id: "video-1",
                        channelID: "UC111",
                        channelTitle: "one",
                        title: "video",
                        publishedAt: now,
                        videoURL: URL(string: "https://example.com/watch?v=1"),
                        thumbnailRemoteURL: nil,
                        thumbnailLocalFilename: nil,
                        fetchedAt: now,
                        searchableText: "video",
                        durationSeconds: 1_500,
                        viewCount: 101
                    )
                ]
            )

            let database = FeedCacheSQLiteDatabase.shared(fileManager: fileManager)
            database.replaceFeedSnapshot(snapshot)
            let thumbnailURL = thumbnailsDirectory.appendingPathComponent("video-1.jpg")
            try Data("image".utf8).write(to: thumbnailURL, options: .atomic)

            let store = FeedCacheStore()
            let result = await store.cacheThumbnail(forVideoID: "video-1")
            let reloaded = database.loadFeedSnapshot()

            XCTAssertEqual(result?.filename, "video-1.jpg")
            XCTAssertEqual(reloaded.videos.first?.thumbnailLocalFilename, "video-1.jpg")
        }
    }
}
