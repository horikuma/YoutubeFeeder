import Foundation
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
                makeDuplicateRemoteSearchSnapshot(
                    channelID: channelID,
                    duplicateVideoID: duplicateVideoID,
                    olderDate: olderDate,
                    newerDate: newerDate
                )
            )

            let remoteCacheStore = RemoteVideoSearchCacheStore()
            await remoteCacheStore.save(
                keyword: "duplicate",
                videos: [
                    makeRemoteSearchDuplicateVideo(
                        id: duplicateVideoID,
                        channelID: channelID,
                        publishedAt: newerDate,
                        fetchedAt: newerDate
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

    func testOpenChannelVideosUsesChannelFallbackWhenRemoteSearchHasOnlyOneVideo() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let channelID = "UC_REMOTE_FALLBACK"
        let selectedVideoID = "remote-only-1"
        let now = ISO8601DateFormatter().date(from: "2026-03-21T03:00:00Z")!

        try await withEnvironment([
            "YOUTUBEFEEDER_FEEDCACHE_BASE_DIR": temporaryRoot.appendingPathComponent("Cache", isDirectory: true).path,
            "YOUTUBEFEEDER_UI_TEST_MODE": "1"
        ]) {
            let remoteCacheStore = RemoteVideoSearchCacheStore()
            await remoteCacheStore.save(
                keyword: "fallback-test",
                videos: [
                    CachedVideo(
                        id: selectedVideoID,
                        channelID: channelID,
                        channelTitle: "Remote Channel",
                        title: "single remote result",
                        publishedAt: now,
                        videoURL: URL(string: "https://example.com/watch?v=\(selectedVideoID)"),
                        thumbnailRemoteURL: nil,
                        thumbnailLocalFilename: nil,
                        fetchedAt: now,
                        searchableText: "single remote result",
                        durationSeconds: 180,
                        viewCount: 99
                    )
                ],
                totalCount: 1,
                fetchedAt: now
            )

            let coordinator = FeedCacheCoordinator(
                channels: [],
                dependencies: FeedCacheDependencies.live()
            )

            let videos = await coordinator.openChannelVideos(
                ChannelVideosRouteContext(
                    channelID: channelID,
                    preferredChannelTitle: "Remote Channel",
                    selectedVideoID: selectedVideoID,
                    prefersAutomaticRefresh: true,
                    routeSource: .remoteSearch
                )
            )

            XCTAssertGreaterThan(videos.count, 1)
            XCTAssertTrue(videos.contains { $0.id == selectedVideoID })
        }
    }
}

private func makeDuplicateRemoteSearchSnapshot(
    channelID: String,
    duplicateVideoID: String,
    olderDate: Date,
    newerDate: Date
) -> FeedCacheSnapshot {
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
}

private func makeRemoteSearchDuplicateVideo(
    id: String,
    channelID: String,
    publishedAt: Date,
    fetchedAt: Date
) -> CachedVideo {
    CachedVideo(
        id: id,
        channelID: channelID,
        channelTitle: "Remote Channel",
        title: "remote copy",
        publishedAt: publishedAt,
        videoURL: URL(string: "https://example.com/watch?v=remote"),
        thumbnailRemoteURL: nil,
        thumbnailLocalFilename: nil,
        fetchedAt: fetchedAt,
        searchableText: "remote copy",
        durationSeconds: 180,
        viewCount: 99
    )
}

@MainActor
