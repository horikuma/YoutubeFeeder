import Foundation
import XCTest
@testable import YoutubeFeeder

final class FeedCacheCoordinatorConcurrencyTests: LoggedTestCase {
    func testMaximumConcurrentChannelRefreshesRemainsThree() {
        XCTAssertEqual(FeedCacheCoordinator.maximumConcurrentChannelRefreshes, 3)
    }

    func testRefreshCycleMetadataCountsHTTP404WithoutPerChannelWarningRequirement() {
        var result = FeedRefreshCycleResult()

        result.record(FeedChannelProcessResult(
            errorMessage: nil,
            fetchedVideoCount: 0,
            uncachedVideoCount: 0,
            conditionalCheckAttempted: true,
            networkFetchAttempted: false,
            httpStatusCode: 404
        ))
        result.record(FeedChannelProcessResult(
            errorMessage: nil,
            fetchedVideoCount: 15,
            uncachedVideoCount: 2,
            conditionalCheckAttempted: true,
            networkFetchAttempted: true,
            httpStatusCode: 200
        ))

        let metadata = result.metadata(
            channelCount: 2,
            forceNetworkFetch: false,
            refreshSource: "automatic",
            cachedVideosBefore: 10,
            cachedVideosAfter: 12
        )

        XCTAssertEqual(metadata["successful_channels"], "2")
        XCTAssertEqual(metadata["failed_channels"], "0")
        XCTAssertEqual(metadata["http_404_channels"], "1")
        XCTAssertEqual(metadata["http_non_2xx_channels"], "1")
        XCTAssertEqual(metadata["zero_fetched_channels"], "1")
        XCTAssertEqual(metadata["fetched_videos_total"], "15")
        XCTAssertEqual(metadata["cached_videos_delta"], "2")
        XCTAssertEqual(result.conditionalCheckAttemptedChannels, 2)
        XCTAssertEqual(result.networkFetchAttemptedChannels, 1)
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
                    RegisteredChannelRecord(channelID: "UC222", addedAt: nil)
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
    func testFullRefreshUsesConditionalFetchWhenSnapshotIsFresh() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let channelID = "UC_FORCE_REFRESH"
        let now = Date(timeIntervalSince1970: 10_000)
        let recorder = FeedRefreshCallRecorder()

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
                checkForUpdates: { _, validationToken in
                    await recorder.recordCheck(
                        validationToken: validationToken,
                        manualTaskVisible: false
                    )
                    return .notModified(
                        FeedFetchMetadata(
                            checkedAt: now,
                            validationToken: FeedValidationToken(
                                etag: "cached-etag",
                                lastModified: "cached-last-modified"
                            ),
                            httpStatusCode: 304
                        )
                    )
                },
                fetchLatestFeed: { _ in
                    await recorder.recordFetch()
                    return (
                        videos: [],
                        metadata: FeedFetchMetadata(
                            checkedAt: now,
                            validationToken: FeedValidationToken(etag: nil, lastModified: nil)
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

            await coordinator.performFullChannelRefresh(refreshSource: "test")
            let snapshot = database.loadFeedSnapshot()
            let callSummary = await recorder.snapshot()

            XCTAssertEqual(callSummary.checkCount, 1)
            XCTAssertEqual(callSummary.fetchCount, 0)
            XCTAssertEqual(callSummary.manualTaskObservedDuringCheck, false)
            XCTAssertEqual(callSummary.validationTokens, ["cached-etag"])
            XCTAssertTrue(snapshot.videos.isEmpty)
            XCTAssertEqual(snapshot.channels.first?.etag, "cached-etag")
        }
    }
}
