import XCTest
@testable import YoutubeFeeder

final class FeedCacheMaintenanceStoreCleanupTests: LoggedTestCase {
    func testRemoveChannelIDDeletesRegisteredChannel() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        try await withFeedCacheBaseDirectory(temporaryRoot.appendingPathComponent("Cache", isDirectory: true)) {
            try ChannelRegistryStore.replaceChannels(
                [
                    RegisteredChannelRecord(channelID: "UC111", addedAt: nil),
                    RegisteredChannelRecord(channelID: "UC222", addedAt: nil)
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
            let snapshot = makeCleanupSnapshot(now: now)

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

private func makeCleanupSnapshot(now: Date) -> FeedCacheSnapshot {
    FeedCacheSnapshot(
        savedAt: now,
        channels: [
            makeCleanupChannelState(channelID: "UC111", channelTitle: "one", now: now),
            makeCleanupChannelState(channelID: "UC999", channelTitle: "orphan", now: now)
        ],
        videos: [
            makeCleanupVideo(
                .init(
                    id: "video-1",
                    channelID: "UC111",
                    channelTitle: "one",
                    title: "kept",
                    publishedAt: now,
                    thumbnailLocalFilename: "video-1.jpg",
                    fetchedAt: now,
                    searchableText: "kept",
                    durationSeconds: 1_500,
                    viewCount: 101
                )
            ),
            makeCleanupVideo(
                .init(
                    id: "video-2",
                    channelID: "UC999",
                    channelTitle: "orphan",
                    title: "removed",
                    publishedAt: now,
                    thumbnailLocalFilename: "video-2.jpg",
                    fetchedAt: now,
                    searchableText: "removed",
                    durationSeconds: 2_100,
                    viewCount: 202
                )
            )
        ]
    )
}

private func makeCleanupChannelState(channelID: String, channelTitle: String, now: Date) -> CachedChannelState {
    CachedChannelState(
        channelID: channelID,
        channelTitle: channelTitle,
        lastAttemptAt: now,
        lastCheckedAt: now,
        lastSuccessAt: now,
        latestPublishedAt: now,
        cachedVideoCount: 1,
        lastError: nil,
        etag: nil,
        lastModified: nil
    )
}

private func makeCleanupVideo(
    _ spec: CleanupVideoSpec
) -> CachedVideo {
    CachedVideo(
        id: spec.id,
        channelID: spec.channelID,
        channelTitle: spec.channelTitle,
        title: spec.title,
        publishedAt: spec.publishedAt,
        videoURL: URL(string: "https://example.com/watch?v=\(spec.id.split(separator: "-").last ?? "")"),
        thumbnailRemoteURL: nil,
        thumbnailLocalFilename: spec.thumbnailLocalFilename,
        fetchedAt: spec.fetchedAt,
        searchableText: spec.searchableText,
        durationSeconds: spec.durationSeconds,
        viewCount: spec.viewCount
    )
}

private struct CleanupVideoSpec {
    let id: String
    let channelID: String
    let channelTitle: String
    let title: String
    let publishedAt: Date
    let thumbnailLocalFilename: String
    let fetchedAt: Date
    let searchableText: String
    let durationSeconds: Int
    let viewCount: Int
}

    func testResetAllStoredDataClearsCacheButLeavesBackupRecoverable() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        try await withFeedCacheBaseDirectory(temporaryRoot.appendingPathComponent("Cache", isDirectory: true)) {
            let now = ISO8601DateFormatter().date(from: "2026-03-15T03:00:00Z")!
            let fixture = try seedResetStoredDataFixture(fileManager: fileManager, temporaryRoot: temporaryRoot, now: now)
            let store = FeedCacheStore()
            let reset = await store.resetAllStoredData()

            XCTAssertEqual(reset.removedVideoCount, 1)
            XCTAssertEqual(reset.removedThumbnailCount, 1)
            XCTAssertFalse(fileManager.fileExists(atPath: fixture.databaseURL.path))
            XCTAssertFalse(fileManager.fileExists(atPath: fixture.thumbnailsDirectory.path))
            XCTAssertFalse(fileManager.fileExists(atPath: fixture.legacyCacheURL.path))
            XCTAssertFalse(fileManager.fileExists(atPath: fixture.legacyCacheSummaryURL.path))
            XCTAssertFalse(fileManager.fileExists(atPath: fixture.legacyRegistryURL.path))
            XCTAssertFalse(fileManager.fileExists(atPath: fixture.legacySearchURL.path))
            XCTAssertFalse(fileManager.fileExists(atPath: fixture.legacySearchSummaryURL.path))
            let reloadedSnapshot = await store.loadSnapshot()
            XCTAssertEqual(reloadedSnapshot.videos.count, 0)
            XCTAssertTrue(fileManager.fileExists(atPath: fixture.backupURL.path))

            _ = try ChannelRegistryTransferStore.import(
                fileManager: fixture.fileManager,
                backend: .localDocuments,
                containerURL: fixture.temporaryRoot
            )
            XCTAssertEqual(ChannelRegistryStore.loadAllChannelIDs(fileManager: fixture.fileManager), ["UC111", "UC222"])
        }
    }

}

private struct ResetStoredDataFixture {
    let fileManager: FileManager
    let temporaryRoot: URL
    let backupURL: URL
    let databaseURL: URL
    let thumbnailsDirectory: URL
    let legacyCacheURL: URL
    let legacyCacheSummaryURL: URL
    let legacyRegistryURL: URL
    let legacySearchURL: URL
    let legacySearchSummaryURL: URL
}

private func seedResetStoredDataFixture(
    fileManager: FileManager,
    temporaryRoot: URL,
    now: Date
) throws -> ResetStoredDataFixture {
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
                RegisteredChannelRecord(channelID: "UC222", addedAt: nil)
            ]
        )
    ).write(to: backupURL, options: .atomic)

    let paths = makeResetStoredDataPaths(fileManager: fileManager)
    try fileManager.createDirectory(at: paths.thumbnailsDirectory, withIntermediateDirectories: true)
    try ChannelRegistryStore.replaceChannels(
        [
            RegisteredChannelRecord(channelID: "UC111", addedAt: nil),
            RegisteredChannelRecord(channelID: "UC222", addedAt: nil)
        ],
        fileManager: fileManager
    )

    let snapshot = makeResetStoredDataSnapshot(now: now)
    let database = FeedCacheSQLiteDatabase.shared(fileManager: fileManager)
    database.replaceFeedSnapshot(snapshot)
    try writeResetStoredDataLegacyFiles(fileManager: fileManager, paths: paths)

    return ResetStoredDataFixture(
        fileManager: fileManager,
        temporaryRoot: temporaryRoot,
        backupURL: backupURL,
        databaseURL: paths.databaseURL,
        thumbnailsDirectory: paths.thumbnailsDirectory,
        legacyCacheURL: paths.legacyCacheURL,
        legacyCacheSummaryURL: paths.legacyCacheSummaryURL,
        legacyRegistryURL: paths.legacyRegistryURL,
        legacySearchURL: paths.legacySearchURL,
        legacySearchSummaryURL: paths.legacySearchSummaryURL
    )
}

private struct ResetStoredDataPaths {
    let databaseURL: URL
    let thumbnailsDirectory: URL
    let legacyCacheURL: URL
    let legacyCacheSummaryURL: URL
    let legacyRegistryURL: URL
    let legacySearchURL: URL
    let legacySearchSummaryURL: URL
}

private func makeResetStoredDataPaths(fileManager: FileManager) -> ResetStoredDataPaths {
    ResetStoredDataPaths(
        databaseURL: FeedCachePaths.databaseURL(fileManager: fileManager),
        thumbnailsDirectory: FeedCachePaths.thumbnailsDirectory(fileManager: fileManager),
        legacyCacheURL: FeedCachePaths.cacheURL(fileManager: fileManager),
        legacyCacheSummaryURL: FeedCachePaths.cacheSummaryURL(fileManager: fileManager),
        legacyRegistryURL: FeedCachePaths.channelRegistryURL(fileManager: fileManager),
        legacySearchURL: FeedCachePaths.remoteSearchCacheURL(keyword: "", fileManager: fileManager),
        legacySearchSummaryURL: FeedCachePaths.remoteSearchCacheSummaryURL(keyword: "", fileManager: fileManager)
    )
}

private func makeResetStoredDataSnapshot(now: Date) -> FeedCacheSnapshot {
    FeedCacheSnapshot(
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
            )
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
            )
        ]
    )
}

private func writeResetStoredDataLegacyFiles(
    fileManager: FileManager,
    paths: ResetStoredDataPaths
) throws {
    try Data("keep".utf8).write(to: paths.thumbnailsDirectory.appendingPathComponent("video-1.jpg"), options: .atomic)
    try Data("legacy-cache".utf8).write(to: paths.legacyCacheURL, options: .atomic)
    try Data("legacy-summary".utf8).write(to: paths.legacyCacheSummaryURL, options: .atomic)
    try Data("legacy-registry".utf8).write(to: paths.legacyRegistryURL, options: .atomic)
    try Data("legacy-search".utf8).write(to: paths.legacySearchURL, options: .atomic)
    try Data("legacy-search-summary".utf8).write(to: paths.legacySearchSummaryURL, options: .atomic)
}
