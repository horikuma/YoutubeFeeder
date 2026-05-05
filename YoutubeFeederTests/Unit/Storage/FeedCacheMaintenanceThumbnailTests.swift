import XCTest
@testable import YoutubeFeeder

final class FeedCacheMaintenanceThumbnailTests: LoggedTestCase {
    func testEvictOldestThumbnailIfNeededRemovesLeastRecentlyAccessedFileFirst() async throws {
        try await withTemporaryFeedCacheBaseDirectory { fileManager in
            let thumbnailsDirectory = FeedCachePaths.thumbnailsDirectory(fileManager: fileManager)
            try fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)

            let now = ISO8601DateFormatter().date(from: "2026-03-15T03:00:00Z")!
            let oldFilename = "video-1.jpg"
            let newFilename = "video-2.jpg"
            let snapshot = FeedCacheSnapshot(savedAt: now, channels: [], videos: [CachedVideo(id: "video-1", channelID: "UC111", channelTitle: "one", title: "oldest", publishedAt: now, videoURL: URL(string: "https://example.com/watch?v=1"), thumbnailRemoteURL: nil, thumbnailLocalFilename: oldFilename, thumbnailLastAccessedAt: now.addingTimeInterval(-300), fetchedAt: now, searchableText: "oldest", durationSeconds: 1_500, viewCount: 101), CachedVideo(id: "video-2", channelID: "UC111", channelTitle: "one", title: "newest", publishedAt: now, videoURL: URL(string: "https://example.com/watch?v=2"), thumbnailRemoteURL: nil, thumbnailLocalFilename: newFilename, thumbnailLastAccessedAt: now, fetchedAt: now, searchableText: "newest", durationSeconds: 1_600, viewCount: 202)])

            let database = FeedCacheSQLiteDatabase.shared(fileManager: fileManager)
            database.replaceFeedSnapshot(snapshot)
            try Data("old".utf8).write(to: thumbnailsDirectory.appendingPathComponent(oldFilename), options: .atomic)
            try Data("new".utf8).write(to: thumbnailsDirectory.appendingPathComponent(newFilename), options: .atomic)

            let store = FeedCacheStore()
            let result = await store.evictOldestThumbnailIfNeeded(maxThumbnailCount: 1)
            let reloaded = database.loadFeedSnapshot()

            XCTAssertEqual(result?.filename, oldFilename)
            XCTAssertFalse(fileManager.fileExists(atPath: thumbnailsDirectory.appendingPathComponent(oldFilename).path))
            XCTAssertTrue(fileManager.fileExists(atPath: thumbnailsDirectory.appendingPathComponent(newFilename).path))
            XCTAssertNil(reloaded.videos.first(where: { $0.id == "video-1" })?.thumbnailLocalFilename)
            XCTAssertEqual(reloaded.videos.first(where: { $0.id == "video-2" })?.thumbnailLocalFilename, newFilename)
        }
    }

    func testTrimThumbnailsIfNeededContinuesUntilBelowLowWatermark() async throws {
        try await withTemporaryFeedCacheBaseDirectory { fileManager in
            let thumbnailsDirectory = FeedCachePaths.thumbnailsDirectory(fileManager: fileManager)
            try fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)

            let now = ISO8601DateFormatter().date(from: "2026-03-15T03:00:00Z")!
            let filenames = ["video-1.jpg", "video-2.jpg", "video-3.jpg"]
            let snapshot = FeedCacheSnapshot(savedAt: now, channels: [], videos: filenames.enumerated().map { offset, filename in CachedVideo(id: "video-\(offset + 1)", channelID: "UC111", channelTitle: "one", title: "video-\(offset + 1)", publishedAt: now, videoURL: URL(string: "https://example.com/watch?v=\(offset + 1)"), thumbnailRemoteURL: nil, thumbnailLocalFilename: filename, thumbnailLastAccessedAt: now.addingTimeInterval(TimeInterval(offset - 10)), fetchedAt: now, searchableText: "video-\(offset + 1)", durationSeconds: 1_500, viewCount: 100 + offset) })

            let database = FeedCacheSQLiteDatabase.shared(fileManager: fileManager)
            database.replaceFeedSnapshot(snapshot)
            try Data("1".utf8).write(to: thumbnailsDirectory.appendingPathComponent(filenames[0]), options: .atomic)
            try Data("22".utf8).write(to: thumbnailsDirectory.appendingPathComponent(filenames[1]), options: .atomic)
            try Data("333".utf8).write(to: thumbnailsDirectory.appendingPathComponent(filenames[2]), options: .atomic)

            let store = FeedCacheStore()
            let result = await store.trimThumbnailsIfNeeded(maxThumbnailCount: 2, minThumbnailCount: 1)
            let reloaded = database.loadFeedSnapshot()

            XCTAssertEqual(result?.removedFilenames, [filenames[0], filenames[1]])
            XCTAssertFalse(fileManager.fileExists(atPath: thumbnailsDirectory.appendingPathComponent(filenames[0]).path))
            XCTAssertFalse(fileManager.fileExists(atPath: thumbnailsDirectory.appendingPathComponent(filenames[1]).path))
            XCTAssertTrue(fileManager.fileExists(atPath: thumbnailsDirectory.appendingPathComponent(filenames[2]).path))
            XCTAssertEqual(reloaded.videos.compactMap(\.thumbnailLocalFilename), [filenames[2]])
        }
    }

    func testCurrentThumbnailCacheStatusReportsBytesAndThresholdJudgement() async throws {
        try await withTemporaryFeedCacheBaseDirectory { fileManager in
            let thumbnailsDirectory = FeedCachePaths.thumbnailsDirectory(fileManager: fileManager)
            try fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)

            let now = ISO8601DateFormatter().date(from: "2026-03-15T03:00:00Z")!
            let snapshot = FeedCacheSnapshot(savedAt: now, channels: [], videos: [CachedVideo(id: "video-1", channelID: "UC111", channelTitle: "one", title: "one", publishedAt: now, videoURL: nil, thumbnailRemoteURL: nil, thumbnailLocalFilename: "video-1.jpg", thumbnailLastAccessedAt: now, fetchedAt: now, searchableText: "one", durationSeconds: 1_500, viewCount: 1), CachedVideo(id: "video-2", channelID: "UC111", channelTitle: "one", title: "two", publishedAt: now, videoURL: nil, thumbnailRemoteURL: nil, thumbnailLocalFilename: "video-2.jpg", thumbnailLastAccessedAt: now, fetchedAt: now, searchableText: "two", durationSeconds: 1_500, viewCount: 2)])

            let database = FeedCacheSQLiteDatabase.shared(fileManager: fileManager)
            database.replaceFeedSnapshot(snapshot)
            try Data("1".utf8).write(to: thumbnailsDirectory.appendingPathComponent("video-1.jpg"), options: .atomic)
            try Data("22".utf8).write(to: thumbnailsDirectory.appendingPathComponent("video-2.jpg"), options: .atomic)

            let store = FeedCacheStore()
            let status = await store.currentThumbnailCacheStatus()
            let thresholds = ThumbnailCacheThresholds(
                maxThumbnailCount: 1,
                minThumbnailCount: 1,
                maxThumbnailBytes: 2,
                minThumbnailBytes: 2
            )

            XCTAssertEqual(status.fileCount, 2)
            XCTAssertEqual(status.totalBytes, 3)
            XCTAssertTrue(status.exceedsUpperBound(thresholds: thresholds))
            XCTAssertTrue(status.exceedsLowerBound(thresholds: thresholds))
        }
    }

}
