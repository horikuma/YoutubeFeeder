import Foundation
import XCTest
@testable import YoutubeFeeder

final class FeedCacheCoordinatorConcurrencyRefreshTests: LoggedTestCase {
    @MainActor
    func testWallClockRecentRefreshEntersExecutionWhileManualTaskIsActive() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let channelID = "UC_RECENT_REFRESH"
        let now = Date(timeIntervalSince1970: 10_000)
        let recorder = FeedRefreshCallRecorder()
        let coordinatorBox = CoordinatorBox()

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
            coordinatorBox.coordinator = FeedCacheCoordinator(
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

            await coordinatorBox.coordinator?.runWallClockChannelRefresh(.recentChannels)
            let callSummary = await recorder.snapshot()

            XCTAssertEqual(callSummary.checkCount, 1)
            XCTAssertEqual(callSummary.fetchCount, 0)
            XCTAssertTrue(callSummary.manualTaskObservedDuringCheck)
        }
    }

    @MainActor
    func testRefreshCycleProgressLogsEveryFiftyChannels() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let now = Date(timeIntervalSince1970: 10_000)
        let channelIDs = (1...51).map { "UC_PROGRESS_\($0)" }

        let (_, output) = try await captureStandardOutput {
            try await withFeedCacheBaseDirectory(temporaryRoot.appendingPathComponent("Cache", isDirectory: true)) {
                FeedCacheSQLiteDatabase.resetShared(fileManager: fileManager)
                defer { FeedCacheSQLiteDatabase.resetShared(fileManager: fileManager) }

                let feedService = YouTubeFeedService(
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
                let coordinator = FeedCacheCoordinator(
                    channels: channelIDs,
                    dependencies: FeedCacheDependencies(
                        store: FeedCacheStore(),
                        feedService: feedService,
                        channelResolver: YouTubeChannelResolver(),
                        searchService: YouTubeSearchService(),
                        remoteSearchCacheStore: RemoteVideoSearchCacheStore(),
                        channelRegistrySyncService: ChannelRegistryCloudflareSyncService(endpointURL: nil)
                    )
                )
                let states = Dictionary(
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
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let channelID = "UC_DROP_RUNNING_REFRESH"
        let recorder = FeedFetchRecorder()

        try await withFeedCacheBaseDirectory(temporaryRoot.appendingPathComponent("Cache", isDirectory: true)) {
            FeedCacheSQLiteDatabase.resetShared(fileManager: fileManager)
            defer { FeedCacheSQLiteDatabase.resetShared(fileManager: fileManager) }
            let database = FeedCacheSQLiteDatabase.shared(fileManager: fileManager)
            database.replaceRegisteredChannels([
                RegisteredChannelRecord(channelID: channelID, addedAt: nil)
            ])

            let feedService = YouTubeFeedService(
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
