import Foundation
import XCTest
@testable import YoutubeFeeder

final class FeedCacheCoordinatorConcurrencyRefreshTests: LoggedTestCase {
    @MainActor
    func testWallClockRecentRefreshEntersExecutionWhileManualTaskIsActive() async throws {
        let channelID = "UC_RECENT_REFRESH"
        let now = Date(timeIntervalSince1970: 10_000)
        let recorder = FeedRefreshCallRecorder()
        let coordinatorBox = CoordinatorBox()

        try await withTemporaryFeedCacheBaseDirectory { fileManager in
            FeedCacheSQLiteDatabase.resetShared(fileManager: fileManager)
            defer { FeedCacheSQLiteDatabase.resetShared(fileManager: fileManager) }
            let database = FeedCacheSQLiteDatabase.shared(fileManager: fileManager)
            database.replaceRegisteredChannels([
                RegisteredChannelRecord(channelID: channelID, addedAt: nil)
            ])
            database.replaceFeedSnapshot(makeConcurrencyRefreshSnapshot(channelID: channelID, now: now))

            let feedService = makeRecentRefreshFeedService(
                now: now,
                coordinatorBox: coordinatorBox,
                recorder: recorder
            )
            coordinatorBox.coordinator = FeedCacheCoordinator(
                channels: [channelID],
                dependencies: makeFeedCacheDependencies(feedService: feedService)
            )

            await coordinatorBox.coordinator?.runWallClockChannelRefresh(.recentChannels)
            let callSummary = await recorder.snapshot()

            XCTAssertEqual(callSummary.checkCount, 1)
            XCTAssertEqual(callSummary.fetchCount, 0)
            XCTAssertTrue(callSummary.manualTaskObservedDuringCheck)
        }
    }

    @MainActor
    func testRefreshCycleProgressLogsEveryFiftyChannels() async throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let channelIDs = (1...51).map { "UC_PROGRESS_\($0)" }

        let (_, output) = try await captureStandardOutput {
            try await withTemporaryFeedCacheBaseDirectory { fileManager in
                FeedCacheSQLiteDatabase.resetShared(fileManager: fileManager)
                defer { FeedCacheSQLiteDatabase.resetShared(fileManager: fileManager) }

                let feedService = makeProgressFeedService(now: now)
                let coordinator = FeedCacheCoordinator(
                    channels: channelIDs,
                    dependencies: makeFeedCacheDependencies(feedService: feedService)
                )
                let states = makeProgressStates(channelIDs: channelIDs, now: now)
                _ = await coordinator.runManualRefreshChannels(
                    channelIDs,
                    states: states,
                    forceNetworkFetch: false,
                    refreshSource: "test"
                )
            }
        }

        let progressLines = unwrappedLogOutput(output)
            .split(separator: "\n")
            .filter { $0.contains("refresh_cycle_progress") }

        XCTAssertEqual(progressLines.count, 2)
        XCTAssertTrue(progressLines.contains { $0.contains(#"processed_channels="50""#) })
        XCTAssertTrue(progressLines.contains { $0.contains(#"processed_channels="51""#) })
    }

    @MainActor
    func testRefreshTriggersAreDroppedWhileRefreshIsRunning() async throws {
        let channelID = "UC_DROP_RUNNING_REFRESH"
        let recorder = FeedFetchRecorder()

        try await withTemporaryFeedCacheBaseDirectory { fileManager in
            FeedCacheSQLiteDatabase.resetShared(fileManager: fileManager)
            defer { FeedCacheSQLiteDatabase.resetShared(fileManager: fileManager) }
            let database = FeedCacheSQLiteDatabase.shared(fileManager: fileManager)
            database.replaceRegisteredChannels([
                RegisteredChannelRecord(channelID: channelID, addedAt: nil)
            ])

            let feedService = makeDropRefreshFeedService(recorder: recorder)
            let coordinator = FeedCacheCoordinator(
                channels: [channelID],
                dependencies: makeFeedCacheDependencies(feedService: feedService)
            )
            coordinator.manualRefreshTask = Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                return nil
            }
            defer {
                coordinator.manualRefreshTask?.cancel()
                coordinator.manualRefreshTask = nil
            }

            _ = await coordinator.refresh(intent: .home)
            _ = await coordinator.refresh(intent: .channel(
                ChannelVideosRouteContext(
                    channelID: channelID,
                    prefersAutomaticRefresh: false,
                    routeSource: .channelBrowse
                )
            ))
            await coordinator.runWallClockChannelRefresh(.allChannels)
            await coordinator.runWallClockChannelRefresh(.recentChannels)

            let fetchedChannelIDs = await recorder.fetchedChannelIDs()
            XCTAssertEqual(fetchedChannelIDs, [])
        }
    }
}

private struct FeedRefreshCallSnapshot {
    let checkCount: Int
    let fetchCount: Int
    let manualTaskObservedDuringCheck: Bool
    let validationTokens: [String?]
}

private actor FeedRefreshCallRecorder {
    private var checkCount = 0
    private var fetchCount = 0
    private var manualTaskObservedDuringCheck = false
    private var validationTokens: [String?] = []

    func recordCheck(validationToken: FeedValidationToken?, manualTaskVisible: Bool) {
        checkCount += 1
        manualTaskObservedDuringCheck = manualTaskObservedDuringCheck || manualTaskVisible
        validationTokens.append(validationToken?.etag)
    }

    func recordFetch() {
        fetchCount += 1
    }

    func snapshot() -> FeedRefreshCallSnapshot {
        FeedRefreshCallSnapshot(
            checkCount: checkCount,
            fetchCount: fetchCount,
            manualTaskObservedDuringCheck: manualTaskObservedDuringCheck,
            validationTokens: validationTokens
        )
    }
}

private func makeFeedCacheDependencies(feedService: YouTubeFeedService) -> FeedCacheDependencies {
    FeedCacheDependencies(
        store: FeedCacheStore(),
        feedService: feedService,
        channelResolver: YouTubeChannelResolver(),
        searchService: YouTubeSearchService(),
        remoteSearchCacheStore: RemoteVideoSearchCacheStore(),
        channelRegistrySyncService: ChannelRegistryCloudflareSyncService(endpointURL: nil)
    )
}

private func makeConcurrencyRefreshSnapshot(channelID: String, now: Date) -> FeedCacheSnapshot {
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
}

private func makeRecentRefreshFeedService(
    now: Date,
    coordinatorBox: CoordinatorBox,
    recorder: FeedRefreshCallRecorder
) -> YouTubeFeedService {
    YouTubeFeedService(
        checkForUpdates: { _, validationToken in
            let manualTaskVisible = await MainActor.run {
                coordinatorBox.coordinator?.manualRefreshTask != nil
            }
            await recorder.recordCheck(
                validationToken: validationToken,
                manualTaskVisible: manualTaskVisible
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
}

private func makeProgressFeedService(now: Date) -> YouTubeFeedService {
    YouTubeFeedService(
        checkForUpdates: { _, _ in
            .notModified(
                FeedFetchMetadata(
                    checkedAt: now,
                    validationToken: FeedValidationToken(etag: nil, lastModified: nil),
                    httpStatusCode: 304
                )
            )
        }
    )
}

private func makeProgressStates(channelIDs: [String], now: Date) -> [String: CachedChannelState] {
    Dictionary(
        uniqueKeysWithValues: channelIDs.map {
            (
                $0,
                CachedChannelState(
                    channelID: $0,
                    channelTitle: "Channel \($0)",
                    lastAttemptAt: now.addingTimeInterval(-60),
                    lastCheckedAt: now.addingTimeInterval(-60),
                    lastSuccessAt: now.addingTimeInterval(-60),
                    latestPublishedAt: now.addingTimeInterval(-60),
                    cachedVideoCount: 0,
                    lastError: nil,
                    etag: nil,
                    lastModified: nil
                )
            )
        }
    )
}

private func makeDropRefreshFeedService(recorder: FeedFetchRecorder) -> YouTubeFeedService {
    YouTubeFeedService(
        fetchLatestFeed: { fetchedChannelID in
            await recorder.record(fetchedChannelID)
            return (
                videos: [],
                metadata: FeedFetchMetadata(
                    checkedAt: Date(timeIntervalSince1970: 10_000),
                    validationToken: FeedValidationToken(etag: nil, lastModified: nil)
                )
            )
        }
    )
}

private final class CoordinatorBox {
    var coordinator: FeedCacheCoordinator?
}

private actor FeedFetchRecorder {
    private var channelIDs: [String] = []

    func record(_ channelID: String) {
        channelIDs.append(channelID)
    }

    func fetchedChannelIDs() -> [String] {
        channelIDs
    }
}
