import XCTest
@testable import YoutubeFeeder

final class FeedCacheMaintenanceTests: LoggedTestCase {
    func testFeedSnapshotPersistsThumbnailLastAccessedAt() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        try await withFeedCacheBaseDirectory(temporaryRoot.appendingPathComponent("Cache", isDirectory: true)) {
            let now = ISO8601DateFormatter().date(from: "2026-03-15T03:00:00Z")!
            let lastAccessedAt = now.addingTimeInterval(120)
            let snapshot = FeedCacheSnapshot(
                savedAt: now,
                channels: [],
                videos: [
                    CachedVideo(
                        id: "video-1",
                        channelID: "UC111",
                        channelTitle: "one",
                        title: "kept",
                        publishedAt: now,
                        videoURL: URL(string: "https://example.com/watch?v=1"),
                        thumbnailRemoteURL: nil,
                        thumbnailLocalFilename: "video-1.jpg",
                        thumbnailLastAccessedAt: lastAccessedAt,
                        fetchedAt: now,
                        searchableText: "kept",
                        durationSeconds: 1_500,
                        viewCount: 101
                    )
                ]
            )

            let database = FeedCacheSQLiteDatabase.shared(fileManager: fileManager)
            database.replaceFeedSnapshot(snapshot)

            let reloaded = database.loadFeedSnapshot()
            XCTAssertEqual(reloaded.videos.first?.thumbnailLastAccessedAt, lastAccessedAt)
        }
    }

    func testRecordThumbnailReferenceUpdatesFeedAndRemoteSearchRows() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        try await withFeedCacheBaseDirectory(temporaryRoot.appendingPathComponent("Cache", isDirectory: true)) {
            let now = ISO8601DateFormatter().date(from: "2026-03-15T03:00:00Z")!
            let accessedAt = now.addingTimeInterval(300)
            let filename = "video-1.jpg"
            let video = CachedVideo(
                id: "video-1",
                channelID: "UC111",
                channelTitle: "one",
                title: "kept",
                publishedAt: now,
                videoURL: URL(string: "https://example.com/watch?v=1"),
                thumbnailRemoteURL: nil,
                thumbnailLocalFilename: filename,
                fetchedAt: now,
                searchableText: "kept",
                durationSeconds: 1_500,
                viewCount: 101
            )

            let database = FeedCacheSQLiteDatabase.shared(fileManager: fileManager)
            database.replaceFeedSnapshot(FeedCacheSnapshot(savedAt: now, channels: [], videos: [video]))
            database.saveRemoteSearchEntry(
                RemoteVideoSearchCacheEntry(
                    keyword: "keyword",
                    videos: [video],
                    totalCount: 1,
                    fetchedAt: now
                )
            )

            let store = FeedCacheStore()
            await store.recordThumbnailReference(filename: filename, accessedAt: accessedAt)

            let snapshot = database.loadFeedSnapshot()
            let remoteEntry = database.loadRemoteSearchEntry(keyword: "keyword")
            XCTAssertEqual(snapshot.videos.first?.thumbnailLastAccessedAt, accessedAt)
            XCTAssertEqual(remoteEntry?.videos.first?.thumbnailLastAccessedAt, accessedAt)
        }
    }
}

