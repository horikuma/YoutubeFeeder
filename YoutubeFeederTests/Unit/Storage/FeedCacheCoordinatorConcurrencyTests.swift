import XCTest
@testable import YoutubeFeeder

final class FeedCacheCoordinatorConcurrencyTests: LoggedTestCase {
    func testMaximumConcurrentChannelRefreshesRemainsThree() {
        XCTAssertEqual(FeedCacheCoordinator.maximumConcurrentChannelRefreshes, 3)
    }

    @MainActor
    func testSyncRegisteredChannelsFromStoreRestoresEmptyInMemoryChannels() throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        try withFeedCacheBaseDirectory(temporaryRoot.appendingPathComponent("Cache", isDirectory: true)) {
            try ChannelRegistryStore.replaceChannels(
                [
                    RegisteredChannelRecord(channelID: "UC111", addedAt: nil),
                    RegisteredChannelRecord(channelID: "UC222", addedAt: nil),
                ],
                fileManager: fileManager
            )

            let coordinator = FeedCacheCoordinator(
                channels: [],
                dependencies: .live()
            )

            XCTAssertEqual(coordinator.channels, [])

            coordinator.syncRegisteredChannelsFromStore(reason: "test")

            XCTAssertEqual(coordinator.channels, ["UC111", "UC222"])
        }
    }

    @MainActor
    func testManualRefreshForcesNetworkFetchEvenWhenSnapshotIsFresh() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let channelID = "UC_FORCE_REFRESH"
        let now = Date(timeIntervalSince1970: 10_000)
        let recorder = FeedFetchRecorder()

        try await withFeedCacheBaseDirectory(temporaryRoot.appendingPathComponent("Cache", isDirectory: true)) {
            FeedCacheSQLiteDatabase.resetShared(fileManager: fileManager)
            defer { FeedCacheSQLiteDatabase.resetShared(fileManager: fileManager) }
            let database = FeedCacheSQLiteDatabase.shared(fileManager: fileManager)
            database.replaceRegisteredChannels([
                RegisteredChannelRecord(channelID: channelID, addedAt: nil)
            ])
            database.replaceFeedSnapshot(
                FeedCacheSnapshot(
                    savedAt: now,
                    channels: [
                        CachedChannelState(
                            channelID: channelID,
                            channelTitle: "Cached Channel",
                            lastAttemptAt: now.addingTimeInterval(-60),
                            lastCheckedAt: now.addingTimeInterval(-60),
                            lastSuccessAt: now.addingTimeInterval(-60),
                            latestPublishedAt: now.addingTimeInterval(-60),
                            cachedVideoCount: 1,
                            lastError: nil,
                            etag: "cached-etag",
                            lastModified: "cached-last-modified"
                        )
                    ],
                    videos: []
                )
            )

            let feedService = YouTubeFeedService(
                fetchLatestFeed: { fetchedChannelID in
                    await recorder.record(fetchedChannelID)
                    return (
                        videos: [
                            YouTubeVideo(
                                id: "forced-video",
                                title: "forced video",
                                channelTitle: "Forced Channel",
                                publishedAt: now,
                                videoURL: URL(string: "https://example.com/watch?v=forced-video"),
                                thumbnailURL: nil,
                                durationSeconds: 600,
                                viewCount: 10
                            )
                        ],
                        metadata: FeedFetchMetadata(
                            checkedAt: now,
                            validationToken: FeedValidationToken(etag: "forced-etag", lastModified: "forced-last-modified")
                        )
                    )
                }
            )
            let coordinator = FeedCacheCoordinator(
                channels: [channelID],
                dependencies: FeedCacheDependencies(
                    store: FeedCacheStore(),
                    feedService: feedService,
                    channelResolver: YouTubeChannelResolver(),
                    searchService: YouTubeSearchService(),
                    remoteSearchCacheStore: RemoteVideoSearchCacheStore(),
                    channelRegistrySyncService: ChannelRegistryCloudflareSyncService(endpointURL: nil)
                )
            )

            await coordinator.performManualRefresh()
            let snapshot = database.loadFeedSnapshot()
            let fetchedChannelIDs = await recorder.fetchedChannelIDs()

            XCTAssertEqual(fetchedChannelIDs, [channelID])
            XCTAssertEqual(snapshot.videos.map(\.id), ["forced-video"])
            XCTAssertEqual(snapshot.channels.first?.etag, "forced-etag")
        }
    }

    private func withFeedCacheBaseDirectory<T>(_ url: URL, operation: () throws -> T) throws -> T {
        let key = "YOUTUBEFEEDER_FEEDCACHE_BASE_DIR"
        let previousValue = ProcessInfo.processInfo.environment[key]
        setenv(key, url.path, 1)
        defer {
            FeedCacheSQLiteDatabase.resetShared(fileManager: .default)
            if let previousValue {
                setenv(key, previousValue, 1)
            } else {
                unsetenv(key)
            }
        }
        return try operation()
    }

    private func withFeedCacheBaseDirectory<T>(_ url: URL, operation: () async throws -> T) async throws -> T {
        let key = "YOUTUBEFEEDER_FEEDCACHE_BASE_DIR"
        let previousValue = ProcessInfo.processInfo.environment[key]
        setenv(key, url.path, 1)
        defer {
            FeedCacheSQLiteDatabase.resetShared(fileManager: .default)
            if let previousValue {
                setenv(key, previousValue, 1)
            } else {
                unsetenv(key)
            }
        }
        return try await operation()
    }
}

private actor FeedFetchRecorder {
    private var channelIDs: [String] = []

    func fetchedChannelIDs() -> [String] {
        channelIDs
    }

    func record(_ channelID: String) {
        channelIDs.append(channelID)
    }
}
