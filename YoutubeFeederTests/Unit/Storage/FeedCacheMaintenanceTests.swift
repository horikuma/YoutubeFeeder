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
                    ),
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

    func testEvictOldestThumbnailIfNeededRemovesLeastRecentlyAccessedFileFirst() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        try await withFeedCacheBaseDirectory(temporaryRoot.appendingPathComponent("Cache", isDirectory: true)) {
            let thumbnailsDirectory = FeedCachePaths.thumbnailsDirectory(fileManager: fileManager)
            try fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)

            let now = ISO8601DateFormatter().date(from: "2026-03-15T03:00:00Z")!
            let oldFilename = "video-1.jpg"
            let newFilename = "video-2.jpg"
            let snapshot = FeedCacheSnapshot(
                savedAt: now,
                channels: [],
                videos: [
                    CachedVideo(
                        id: "video-1",
                        channelID: "UC111",
                        channelTitle: "one",
                        title: "oldest",
                        publishedAt: now,
                        videoURL: URL(string: "https://example.com/watch?v=1"),
                        thumbnailRemoteURL: nil,
                        thumbnailLocalFilename: oldFilename,
                        thumbnailLastAccessedAt: now.addingTimeInterval(-300),
                        fetchedAt: now,
                        searchableText: "oldest",
                        durationSeconds: 1_500,
                        viewCount: 101
                    ),
                    CachedVideo(
                        id: "video-2",
                        channelID: "UC111",
                        channelTitle: "one",
                        title: "newest",
                        publishedAt: now,
                        videoURL: URL(string: "https://example.com/watch?v=2"),
                        thumbnailRemoteURL: nil,
                        thumbnailLocalFilename: newFilename,
                        thumbnailLastAccessedAt: now,
                        fetchedAt: now,
                        searchableText: "newest",
                        durationSeconds: 1_600,
                        viewCount: 202
                    ),
                ]
            )

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
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        try await withFeedCacheBaseDirectory(temporaryRoot.appendingPathComponent("Cache", isDirectory: true)) {
            let thumbnailsDirectory = FeedCachePaths.thumbnailsDirectory(fileManager: fileManager)
            try fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)

            let now = ISO8601DateFormatter().date(from: "2026-03-15T03:00:00Z")!
            let filenames = ["video-1.jpg", "video-2.jpg", "video-3.jpg"]
            let snapshot = FeedCacheSnapshot(
                savedAt: now,
                channels: [],
                videos: filenames.enumerated().map { offset, filename in
                    CachedVideo(
                        id: "video-\(offset + 1)",
                        channelID: "UC111",
                        channelTitle: "one",
                        title: "video-\(offset + 1)",
                        publishedAt: now,
                        videoURL: URL(string: "https://example.com/watch?v=\(offset + 1)"),
                        thumbnailRemoteURL: nil,
                        thumbnailLocalFilename: filename,
                        thumbnailLastAccessedAt: now.addingTimeInterval(TimeInterval(offset - 10)),
                        fetchedAt: now,
                        searchableText: "video-\(offset + 1)",
                        durationSeconds: 1_500,
                        viewCount: 100 + offset
                    )
                }
            )

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

    func testRemoveChannelIDDeletesRegisteredChannel() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        try await withFeedCacheBaseDirectory(temporaryRoot.appendingPathComponent("Cache", isDirectory: true)) {
            try ChannelRegistryStore.replaceChannels(
                [
                    RegisteredChannelRecord(channelID: "UC111", addedAt: nil),
                    RegisteredChannelRecord(channelID: "UC222", addedAt: nil),
                ],
                fileManager: fileManager
            )

            XCTAssertTrue(try ChannelRegistryStore.removeChannelID("UC111", fileManager: fileManager))
            XCTAssertEqual(ChannelRegistryStore.loadAllChannelIDs(fileManager: fileManager), ["UC222"])
        }
    }

    func testConsistencyMaintenanceRemovesDetachedVideosAndThumbnails() async throws {
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
                channels: [
                    CachedChannelState(
                        channelID: "UC111",
                        channelTitle: "one",
                        lastAttemptAt: now,
                        lastCheckedAt: now,
                        lastSuccessAt: now,
                        latestPublishedAt: now,
                        cachedVideoCount: 1,
                        lastError: nil,
                        etag: nil,
                        lastModified: nil
                    ),
                    CachedChannelState(
                        channelID: "UC999",
                        channelTitle: "orphan",
                        lastAttemptAt: now,
                        lastCheckedAt: now,
                        lastSuccessAt: now,
                        latestPublishedAt: now,
                        cachedVideoCount: 1,
                        lastError: nil,
                        etag: nil,
                        lastModified: nil
                    ),
                ],
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
                        fetchedAt: now,
                        searchableText: "kept",
                        durationSeconds: 1_500,
                        viewCount: 101
                    ),
                    CachedVideo(
                        id: "video-2",
                        channelID: "UC999",
                        channelTitle: "orphan",
                        title: "removed",
                        publishedAt: now,
                        videoURL: URL(string: "https://example.com/watch?v=2"),
                        thumbnailRemoteURL: nil,
                        thumbnailLocalFilename: "video-2.jpg",
                        fetchedAt: now,
                        searchableText: "removed",
                        durationSeconds: 2_100,
                        viewCount: 202
                    ),
                ]
            )

            let store = FeedCacheStore()
            let database = FeedCacheSQLiteDatabase.shared(fileManager: fileManager)
            database.replaceFeedSnapshot(snapshot)
            try Data("keep".utf8).write(to: thumbnailsDirectory.appendingPathComponent("video-1.jpg"), options: .atomic)
            try Data("drop".utf8).write(to: thumbnailsDirectory.appendingPathComponent("video-2.jpg"), options: .atomic)
            try Data("orphan".utf8).write(to: thumbnailsDirectory.appendingPathComponent("orphan.jpg"), options: .atomic)

            let result = await store.performConsistencyMaintenance(activeChannelIDs: ["UC111"], force: true, now: now)

            XCTAssertEqual(result?.removedVideoCount, 1)
            XCTAssertEqual(result?.removedThumbnailCount, 2)

            let savedSnapshot = await store.loadSnapshot()
            XCTAssertEqual(savedSnapshot.channels.map(\.channelID), ["UC111"])
            XCTAssertEqual(savedSnapshot.channels.first?.cachedVideoCount, 1)
            XCTAssertEqual(savedSnapshot.videos.map(\.channelID), ["UC111"])
            XCTAssertTrue(fileManager.fileExists(atPath: thumbnailsDirectory.appendingPathComponent("video-1.jpg").path))
            XCTAssertFalse(fileManager.fileExists(atPath: thumbnailsDirectory.appendingPathComponent("video-2.jpg").path))
            XCTAssertFalse(fileManager.fileExists(atPath: thumbnailsDirectory.appendingPathComponent("orphan.jpg").path))
        }
    }

    func testResetAllStoredDataClearsCacheButLeavesBackupRecoverable() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let backupURL = temporaryRoot
            .appendingPathComponent("YoutubeFeeder", isDirectory: true)
            .appendingPathComponent("channel-registry.json")
        try fileManager.createDirectory(at: backupURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(
            ChannelRegistryTransferDocument(
                channels: [
                    RegisteredChannelRecord(channelID: "UC111", addedAt: nil),
                    RegisteredChannelRecord(channelID: "UC222", addedAt: nil),
                ]
            )
        ).write(to: backupURL, options: .atomic)

        try await withFeedCacheBaseDirectory(temporaryRoot.appendingPathComponent("Cache", isDirectory: true)) {
            let databaseURL = FeedCachePaths.databaseURL(fileManager: fileManager)
            let thumbnailsDirectory = FeedCachePaths.thumbnailsDirectory(fileManager: fileManager)
            let legacyCacheURL = FeedCachePaths.cacheURL(fileManager: fileManager)
            let legacyCacheSummaryURL = FeedCachePaths.cacheSummaryURL(fileManager: fileManager)
            let legacyRegistryURL = FeedCachePaths.channelRegistryURL(fileManager: fileManager)
            let legacySearchURL = FeedCachePaths.remoteSearchCacheURL(keyword: "", fileManager: fileManager)
            let legacySearchSummaryURL = FeedCachePaths.remoteSearchCacheSummaryURL(keyword: "", fileManager: fileManager)
            try fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
            try ChannelRegistryStore.replaceChannels(
                [
                    RegisteredChannelRecord(channelID: "UC111", addedAt: nil),
                    RegisteredChannelRecord(channelID: "UC222", addedAt: nil),
                ],
                fileManager: fileManager
            )

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
                        cachedVideoCount: 1,
                        lastError: nil,
                        etag: nil,
                        lastModified: nil
                    ),
                ],
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
                        fetchedAt: now,
                        searchableText: "kept",
                        durationSeconds: 1_500,
                        viewCount: 101
                    ),
                ]
            )
            let database = FeedCacheSQLiteDatabase.shared(fileManager: fileManager)
            database.replaceFeedSnapshot(snapshot)
            try Data("keep".utf8).write(to: thumbnailsDirectory.appendingPathComponent("video-1.jpg"), options: .atomic)
            try Data("legacy-cache".utf8).write(to: legacyCacheURL, options: .atomic)
            try Data("legacy-summary".utf8).write(to: legacyCacheSummaryURL, options: .atomic)
            try Data("legacy-registry".utf8).write(to: legacyRegistryURL, options: .atomic)
            try Data("legacy-search".utf8).write(to: legacySearchURL, options: .atomic)
            try Data("legacy-search-summary".utf8).write(to: legacySearchSummaryURL, options: .atomic)

            let store = FeedCacheStore()
            let reset = await store.resetAllStoredData()

            XCTAssertEqual(reset.removedVideoCount, 1)
            XCTAssertEqual(reset.removedThumbnailCount, 1)
            XCTAssertFalse(fileManager.fileExists(atPath: databaseURL.path))
            XCTAssertFalse(fileManager.fileExists(atPath: thumbnailsDirectory.path))
            XCTAssertFalse(fileManager.fileExists(atPath: legacyCacheURL.path))
            XCTAssertFalse(fileManager.fileExists(atPath: legacyCacheSummaryURL.path))
            XCTAssertFalse(fileManager.fileExists(atPath: legacyRegistryURL.path))
            XCTAssertFalse(fileManager.fileExists(atPath: legacySearchURL.path))
            XCTAssertFalse(fileManager.fileExists(atPath: legacySearchSummaryURL.path))
            let reloadedSnapshot = await store.loadSnapshot()
            XCTAssertEqual(reloadedSnapshot.videos.count, 0)
            XCTAssertTrue(fileManager.fileExists(atPath: backupURL.path))

            _ = try ChannelRegistryTransferStore.import(
                fileManager: fileManager,
                backend: .localDocuments,
                containerURL: temporaryRoot
            )
            XCTAssertEqual(ChannelRegistryStore.loadAllChannelIDs(fileManager: fileManager), ["UC111", "UC222"])
        }
    }

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
                    ),
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
                    ),
                ]
            )

            let store = FeedCacheStore()
            let database = FeedCacheSQLiteDatabase.shared(fileManager: fileManager)
            database.replaceFeedSnapshot(snapshot)

            let visibleVideos = await store.loadVideos(
                query: VideoQuery(limit: .max, channelID: "UC111", keyword: nil, sortOrder: .publishedDescending, excludeShorts: true)
            )

            XCTAssertEqual(visibleVideos.map(\.id), ["video-visible"])
        }
    }

    private func withFeedCacheBaseDirectory<T>(_ url: URL, operation: () async throws -> T) async throws -> T {
        let key = "YOUTUBEFEEDER_FEEDCACHE_BASE_DIR"
        let previousValue = ProcessInfo.processInfo.environment[key]
        setenv(key, url.path, 1)
        defer {
            FeedCacheSQLiteDatabase.resetShared()
            if let previousValue {
                setenv(key, previousValue, 1)
            } else {
                unsetenv(key)
            }
        }
        return try await operation()
    }
}
