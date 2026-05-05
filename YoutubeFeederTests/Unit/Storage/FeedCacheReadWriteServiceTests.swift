import Foundation
import XCTest
@testable import YoutubeFeeder

final class FeedCacheReadWriteServiceTests: LoggedTestCase {
    func testLoadRemoteSearchSnapshotReadsCacheWithoutMutatingEntries() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let fetchedAt = ISO8601DateFormatter().date(from: "2026-03-24T03:00:00Z")!
        let channelID = "UC_REMOTE_READ"

        try await withFeedCacheEnvironment(baseDirectory: temporaryRoot.appendingPathComponent("Cache", isDirectory: true)) {
            let remoteCacheStore = RemoteVideoSearchCacheStore()
            await remoteCacheStore.save(
                keyword: "read-snapshot",
                videos: [
                    CachedVideo(
                        id: "video-remote-read",
                        channelID: channelID,
                        channelTitle: "Remote Read",
                        title: "read snapshot",
                        publishedAt: fetchedAt,
                        videoURL: URL(string: "https://example.com/watch?v=video-remote-read"),
                        thumbnailRemoteURL: nil,
                        thumbnailLocalFilename: nil,
                        fetchedAt: fetchedAt,
                        searchableText: "read snapshot",
                        durationSeconds: 300,
                        viewCount: 20
                    )
                ],
                totalCount: 1,
                fetchedAt: fetchedAt
            )

            let readService = FeedCacheReadService(
                store: FeedCacheStore(),
                remoteSearchCacheStore: remoteCacheStore
            )

            let entryBefore = await remoteCacheStore.load(keyword: "read-snapshot")
            let snapshot = await readService.loadRemoteSearchSnapshot(
                keyword: "read-snapshot",
                limit: 20,
                cacheLifetime: 60,
                now: fetchedAt
            )
            let entryAfter = await remoteCacheStore.load(keyword: "read-snapshot")

            XCTAssertEqual(snapshot?.videos.map(\.id), ["video-remote-read"])
            XCTAssertEqual(snapshot?.source, .remoteCache)
            XCTAssertEqual(entryAfter, entryBefore)
        }
    }

    func testLoadMergedVideosForChannelDoesNotMutateCaches() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let channelID = "UC_READ_SERVICE"
        let duplicateVideoID = "duplicate-video"
        let olderDate = ISO8601DateFormatter().date(from: "2026-03-20T03:00:00Z")!
        let newerDate = ISO8601DateFormatter().date(from: "2026-03-21T03:00:00Z")!

        try await withFeedCacheEnvironment(baseDirectory: temporaryRoot.appendingPathComponent("Cache", isDirectory: true)) {
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
                keyword: "read-service",
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

            let readService = FeedCacheReadService(
                store: FeedCacheStore(),
                remoteSearchCacheStore: remoteCacheStore
            )

            let snapshotBefore = database.loadFeedSnapshot()
            let remoteEntryBefore = await remoteCacheStore.load(keyword: "read-service")

            let videos = await readService.loadMergedVideosForChannel(channelID)

            let snapshotAfter = database.loadFeedSnapshot()
            let remoteEntryAfter = await remoteCacheStore.load(keyword: "read-service")

            XCTAssertEqual(videos.count, 1)
            XCTAssertEqual(videos.first?.title, "remote copy")
            assertSnapshot(snapshotAfter, matches: snapshotBefore)
            XCTAssertEqual(remoteEntryAfter?.videos, remoteEntryBefore?.videos)
            XCTAssertEqual(remoteEntryAfter?.totalCount, remoteEntryBefore?.totalCount)
            XCTAssertEqual(remoteEntryAfter?.fetchedAt, remoteEntryBefore?.fetchedAt)
        }
    }

    func testLoadRefreshStateDoesNotPersistBootstrap() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let channelID = "UC_REFRESH_STATE"
        let now = ISO8601DateFormatter().date(from: "2026-03-22T03:00:00Z")!

        try await withFeedCacheEnvironment(baseDirectory: temporaryRoot.appendingPathComponent("Cache", isDirectory: true)) {
            let database = FeedCacheSQLiteDatabase.shared(fileManager: fileManager)
            database.replaceFeedSnapshot(
                FeedCacheSnapshot(
                    savedAt: now,
                    channels: [
                        CachedChannelState(
                            channelID: channelID,
                            channelTitle: "Refresh Channel",
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
                            id: "video-refresh",
                            channelID: channelID,
                            channelTitle: "Refresh Channel",
                            title: "video",
                            publishedAt: now,
                            videoURL: URL(string: "https://example.com/watch?v=video-refresh"),
                            thumbnailRemoteURL: nil,
                            thumbnailLocalFilename: nil,
                            fetchedAt: now,
                            searchableText: "video",
                            durationSeconds: 600,
                            viewCount: 10
                        )
                    ]
                )
            )

            let readService = FeedCacheReadService(
                store: FeedCacheStore(),
                remoteSearchCacheStore: RemoteVideoSearchCacheStore()
            )

            let bootstrapURL = FeedCachePaths.bootstrapURL(fileManager: fileManager)
            let snapshotBefore = database.loadFeedSnapshot()

            let state = await readService.loadRefreshState(.init(
                channels: [channelID],
                freshnessInterval: 60,
                videoQuery: VideoQuery(limit: 20, channelID: nil, keyword: nil, sortOrder: .publishedDescending, excludeShorts: true),
                currentChannelID: nil,
                isRunning: false,
                lastError: nil,
                includesVideos: true
            ))

            let snapshotAfter = database.loadFeedSnapshot()

            XCTAssertEqual(state.progress.cachedVideos, 1)
            XCTAssertEqual(state.maintenanceItems.count, 1)
            XCTAssertEqual(state.videos?.count, 1)
            assertSnapshot(snapshotAfter, matches: snapshotBefore)
            XCTAssertFalse(fileManager.fileExists(atPath: bootstrapURL.path))
        }
    }
}

