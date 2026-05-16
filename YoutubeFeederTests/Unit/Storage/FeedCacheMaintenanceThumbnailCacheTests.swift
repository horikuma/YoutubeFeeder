import XCTest
@testable import YoutubeFeeder

final class FeedCacheMaintenanceThumbnailCacheTests: LoggedTestCase {

    func testCacheThumbnailFallsBackToNextCandidateAndPersistsFilename() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        try await withFeedCacheBaseDirectory(temporaryRoot.appendingPathComponent("Cache", isDirectory: true)) {
            let thumbnailsDirectory = FeedCachePaths.thumbnailsDirectory(fileManager: fileManager)
            try fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)

            let now = ISO8601DateFormatter().date(from: "2026-03-15T03:00:00Z")!
            let primaryFilename = "video-1.jpg"
            let fallbackFilename = "video-1.webp"
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
            let store = FeedCacheStore()
            var attempt = 0
            let result = await store.cacheThumbnail(videoID: "video-1") { url in
                attempt += 1
                if attempt == 1 {
                    throw URLError(.badServerResponse)
                }
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data("image".utf8), response)
            }
            let reloaded = database.loadFeedSnapshot()

            XCTAssertEqual(result, primaryFilename)
            XCTAssertTrue(fileManager.fileExists(atPath: thumbnailsDirectory.appendingPathComponent(primaryFilename).path))
            XCTAssertEqual(reloaded.videos.first?.thumbnailLocalFilename, primaryFilename)
            XCTAssertTrue(fileManager.fileExists(atPath: thumbnailsDirectory.appendingPathComponent(primaryFilename).path) == false || primaryFilename != fallbackFilename)
        }
    }

}
