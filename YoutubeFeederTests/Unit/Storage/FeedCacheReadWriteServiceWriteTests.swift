import Foundation
import XCTest
@testable import YoutubeFeeder

final class FeedCacheReadWriteServiceWriteTests: LoggedTestCase {
    func testPersistBootstrapWritesSnapshotThroughWriteService() async throws {
        let now = ISO8601DateFormatter().date(from: "2026-03-23T03:00:00Z")!
        let progress = CacheProgress(totalChannels: 1, cachedChannels: 1, cachedVideos: 3, cachedThumbnails: 2, currentChannelID: "UC_BOOTSTRAP", currentChannelNumber: 1, lastUpdatedAt: now, isRunning: false, lastError: nil)
        let maintenanceItems = [ChannelMaintenanceItem(id: "UC_BOOTSTRAP", channelID: "UC_BOOTSTRAP", channelTitle: "Bootstrap Channel", lastSuccessAt: now, lastCheckedAt: now, latestPublishedAt: now, cachedVideoCount: 3, lastError: nil, freshness: .fresh)]

        try await withTemporaryFeedCacheBaseDirectory { _ in
            let writeService = FeedCacheWriteService(
                store: FeedCacheStore(),
                remoteSearchCacheStore: RemoteVideoSearchCacheStore()
            )

            await writeService.persistBootstrap(progress: progress, maintenanceItems: maintenanceItems)

            let bootstrapURL = FeedCachePaths.bootstrapURL(fileManager: fileManager)
            let data = try XCTUnwrap(Data(contentsOf: bootstrapURL))
            let decoder = FeedCachePersistenceCoders.makeDecoder()
            let bootstrap = try decoder.decode(FeedBootstrapSnapshot.self, from: data)

            XCTAssertEqual(bootstrap.progress.totalChannels, 1)
            XCTAssertEqual(bootstrap.progress.cachedVideos, 3)
            XCTAssertEqual(bootstrap.maintenanceItems.map(\.channelID), ["UC_BOOTSTRAP"])
        }
    }

    func testLoadSnapshotIncludesPlaylistStateThroughWriteService() async throws {
        let now = ISO8601DateFormatter().date(from: "2026-03-26T03:00:00Z")!
        let channelID = "UC_PLAYLIST_SNAPSHOT"
        let playlistID = "PL_PLAYLIST_SNAPSHOT"
        let playlistItems = [PlaylistBrowseItem(id: playlistID, playlistID: playlistID, channelID: channelID, channelTitle: "Playlist Channel", title: "Playlist title", description: "Playlist description", publishedAt: now, itemCount: 12, thumbnailURL: URL(string: "https://example.com/playlist.jpg"), firstVideoID: "playlist-video-1", firstVideoThumbnailURL: URL(string: "https://example.com/playlist-video-1.jpg"))]
        let playlistPage = PlaylistBrowseVideosPage(playlistID: playlistID, videos: [PlaylistBrowseVideo(id: "playlist-video-1", channelID: channelID, channelTitle: "Playlist Channel", title: "Playlist video", publishedAt: now, videoURL: URL(string: "https://example.com/watch?v=playlist-video-1"), thumbnailURL: URL(string: "https://example.com/playlist-video-1.jpg"), durationSeconds: 180, viewCount: 42)], totalCount: 1, fetchedAt: now, nextPageToken: "PAGE_2")

        try await withTemporaryFeedCacheBaseDirectory { _ in
            let writeService = FeedCacheWriteService(
                store: FeedCacheStore(),
                remoteSearchCacheStore: RemoteVideoSearchCacheStore()
            )

            await writeService.savePlaylistItems(playlistItems, channelID: channelID)
            await writeService.savePlaylistVideosPage(playlistPage)

            let readService = FeedCacheReadService(
                store: FeedCacheStore(),
                remoteSearchCacheStore: RemoteVideoSearchCacheStore()
            )
            let snapshot = await readService.loadSnapshot()

            XCTAssertEqual(snapshot.playlists.playlistsByChannelID[channelID], playlistItems)
            XCTAssertEqual(snapshot.playlists.playlistPagesByPlaylistID[playlistID], playlistPage)
            XCTAssertEqual(
                snapshot.playlists.playlistContinuousPlayURLsByPlaylistID[playlistID],
                URL(string: "https://www.youtube.com/playlist?list=\(playlistID)")
            )
        }
    }

    func testLoadSnapshotIncludesChannelNextPageTokenThroughWriteService() async throws {
        let now = ISO8601DateFormatter().date(from: "2026-03-26T04:00:00Z")!
        let channelID = "UC_CHANNEL_PAGE_TOKEN"

        try await withTemporaryFeedCacheBaseDirectory { fileManager in
            seedPagingSnapshot(fileManager: fileManager, channelID: channelID, now: now)
            let writeService = FeedCacheWriteService(
                store: FeedCacheStore(),
                remoteSearchCacheStore: RemoteVideoSearchCacheStore()
            )
            await writeService.saveChannelNextPageToken("PAGE_2", channelID: channelID)

            let readService = FeedCacheReadService(
                store: FeedCacheStore(),
                remoteSearchCacheStore: RemoteVideoSearchCacheStore()
            )
            let snapshot = await readService.loadSnapshot()

            XCTAssertEqual(snapshot.channelNextPageTokenByChannelID[channelID], "PAGE_2")
            XCTAssertEqual(snapshot.channelBrowseItems(channelIDs: [channelID]).first?.channelID, channelID)
        }
    }

    func testClearRemoteSearchRemovesPersistedCacheThroughWriteService() async throws {
        let fetchedAt = ISO8601DateFormatter().date(from: "2026-03-25T03:00:00Z")!

        try await withTemporaryFeedCacheBaseDirectory { _ in
            let remoteCacheStore = RemoteVideoSearchCacheStore()
            await remoteCacheStore.save(
                keyword: "clear-target",
                videos: [],
                totalCount: 0,
                fetchedAt: fetchedAt
            )

            let writeService = FeedCacheWriteService(
                store: FeedCacheStore(),
                remoteSearchCacheStore: remoteCacheStore
            )

            await writeService.clearRemoteSearch(keyword: "clear-target")

            let entry = await remoteCacheStore.load(keyword: "clear-target")
            XCTAssertNil(entry)
        }
    }
}

private func seedPagingSnapshot(fileManager: FileManager, channelID: String, now: Date) {
    let database = FeedCacheSQLiteDatabase.shared(fileManager: fileManager)
    database.replaceFeedSnapshot(
        FeedCacheSnapshot(
            savedAt: now,
            channels: [
                CachedChannelState(
                    channelID: channelID,
                    channelTitle: "Paging Channel",
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
                    id: "page-video-1",
                    channelID: channelID,
                    channelTitle: "Paging Channel",
                    title: "Page video",
                    publishedAt: now,
                    videoURL: URL(string: "https://example.com/watch?v=page-video-1"),
                    thumbnailRemoteURL: nil,
                    thumbnailLocalFilename: nil,
                    fetchedAt: now,
                    searchableText: "page video",
                    durationSeconds: 90,
                    viewCount: 1
                )
            ]
        )
    )
}
