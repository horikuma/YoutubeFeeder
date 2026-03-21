import XCTest
@testable import YoutubeFeeder

@MainActor
final class FeedCacheCoordinatorRemoteSearchTests: LoggedTestCase {
    func testLoadVideosForChannelDeduplicatesSameVideoIDAcrossFeedCacheAndRemoteSearch() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let channelID = "UC_DUPLICATE"
        let duplicateVideoID = "hxKe2aDUjZE"
        let olderDate = ISO8601DateFormatter().date(from: "2026-03-20T03:00:00Z")!
        let newerDate = ISO8601DateFormatter().date(from: "2026-03-21T03:00:00Z")!

        try await withEnvironment([
            "YOUTUBEFEEDER_FEEDCACHE_BASE_DIR": temporaryRoot.appendingPathComponent("Cache", isDirectory: true).path
        ]) {
            FeedCacheSQLiteDatabase.resetShared(fileManager: fileManager)
            defer { FeedCacheSQLiteDatabase.resetShared(fileManager: fileManager) }
            let database = FeedCacheSQLiteDatabase.shared(fileManager: fileManager)
            database.replaceFeedSnapshot(
                FeedCacheSnapshot(
                    savedAt: newerDate,
                    channels: [
                        CachedChannelState(
                            channelID: channelID,
                            channelTitle: "Local Channel",
                            lastAttemptAt: olderDate,
                            lastCheckedAt: olderDate,
                            lastSuccessAt: olderDate,
                            latestPublishedAt: olderDate,
                            cachedVideoCount: 1,
                            lastError: nil,
                            etag: nil,
                            lastModified: nil
                        )
                    ],
                    videos: [
                        CachedVideo(
                            id: duplicateVideoID,
                            channelID: channelID,
                            channelTitle: "Local Channel",
                            title: "local copy",
                            publishedAt: olderDate,
                            videoURL: URL(string: "https://example.com/watch?v=local"),
                            thumbnailRemoteURL: nil,
                            thumbnailLocalFilename: nil,
                            fetchedAt: olderDate,
                            searchableText: "local copy",
                            durationSeconds: 120,
                            viewCount: 10
                        )
                    ]
                )
            )

            let remoteCacheStore = RemoteVideoSearchCacheStore()
            await remoteCacheStore.save(
                keyword: "duplicate",
                videos: [
                    CachedVideo(
                        id: duplicateVideoID,
                        channelID: channelID,
                        channelTitle: "Remote Channel",
                        title: "remote copy",
                        publishedAt: newerDate,
                        videoURL: URL(string: "https://example.com/watch?v=remote"),
                        thumbnailRemoteURL: nil,
                        thumbnailLocalFilename: nil,
                        fetchedAt: newerDate,
                        searchableText: "remote copy",
                        durationSeconds: 180,
                        viewCount: 99
                    )
                ],
                totalCount: 1,
                fetchedAt: newerDate
            )

            let coordinator = FeedCacheCoordinator(
                channels: [],
                dependencies: FeedCacheDependencies.live()
            )

            let videos = await coordinator.loadVideosForChannel(channelID)

            XCTAssertEqual(videos.count, 1)
            XCTAssertEqual(videos.first?.id, duplicateVideoID)
            XCTAssertEqual(videos.first?.title, "remote copy")
            XCTAssertEqual(videos.first?.channelTitle, "Remote Channel")
            XCTAssertEqual(videos.first?.publishedAt, newerDate)
        }
    }

    func testForceRefreshPersistsRemoteSearchResultToCache() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        try await withEnvironment([
            "YOUTUBEFEEDER_FEEDCACHE_BASE_DIR": temporaryRoot.appendingPathComponent("Cache", isDirectory: true).path,
            "YOUTUBEFEEDER_UI_TEST_MODE": "1"
        ]) {
            let coordinator = FeedCacheCoordinator(
                channels: [],
                dependencies: FeedCacheDependencies.live()
            )

            let freshResult = await coordinator.searchRemoteVideos(
                keyword: "ゆっくり実況",
                limit: 100,
                forceRefresh: true
            )
            let cachedSnapshot = await coordinator.loadRemoteSearchSnapshot(
                keyword: "ゆっくり実況",
                limit: 100
            )

            XCTAssertEqual(freshResult.videos.first?.id, "remote-refresh-001")
            XCTAssertEqual(cachedSnapshot.videos.first?.id, "remote-refresh-001")
            XCTAssertEqual(cachedSnapshot.totalCount, 2)
            XCTAssertEqual(cachedSnapshot.source, .remoteCache)
            XCTAssertNotNil(cachedSnapshot.fetchedAt)
        }
    }

    func testForceRefreshPersistsEvenIfCallerTaskIsCancelled() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        try await withEnvironment([
            "YOUTUBEFEEDER_FEEDCACHE_BASE_DIR": temporaryRoot.appendingPathComponent("Cache", isDirectory: true).path,
            "YOUTUBEFEEDER_UI_TEST_MODE": "1"
        ]) {
            let coordinator = FeedCacheCoordinator(
                channels: [],
                dependencies: FeedCacheDependencies.live()
            )

            let refreshTask = Task { @MainActor in
                await coordinator.searchRemoteVideos(
                    keyword: "ゆっくり実況",
                    limit: 100,
                    forceRefresh: true
                )
            }

            try? await Task.sleep(nanoseconds: 100_000_000)
            refreshTask.cancel()
            _ = await refreshTask.value
            try? await Task.sleep(nanoseconds: 1_200_000_000)

            let cachedSnapshot = await coordinator.loadRemoteSearchSnapshot(
                keyword: "ゆっくり実況",
                limit: 100
            )

            XCTAssertEqual(cachedSnapshot.videos.first?.id, "remote-refresh-001")
            XCTAssertEqual(cachedSnapshot.totalCount, 2)
            XCTAssertEqual(cachedSnapshot.source, .remoteCache)
            XCTAssertNotNil(cachedSnapshot.fetchedAt)
        }
    }

    private func withEnvironment<T>(
        _ overrides: [String: String],
        operation: () async throws -> T
    ) async throws -> T {
        var previousValues: [String: String?] = [:]
        for key in overrides.keys {
            previousValues[key] = ProcessInfo.processInfo.environment[key]
        }

        for (key, value) in overrides {
            setenv(key, value, 1)
        }

        defer {
            FeedCacheSQLiteDatabase.resetShared()
            for (key, previousValue) in previousValues {
                if let previousValue {
                    setenv(key, previousValue, 1)
                } else {
                    unsetenv(key)
                }
            }
        }

        return try await operation()
    }
}
