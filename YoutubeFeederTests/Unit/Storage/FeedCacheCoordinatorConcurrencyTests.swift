import Darwin
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
                checkForUpdates: { fetchedChannelID, validationToken in
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
                checkForUpdates: { fetchedChannelID, validationToken in
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

        let progressLines = Self.unwrappedLogOutput(output)
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

            await coordinator.refreshCacheManually()
            await coordinator.refreshChannelManually(channelID)
            await coordinator.runWallClockChannelRefresh(.allChannels)
            await coordinator.runWallClockChannelRefresh(.recentChannels)

            let fetchedChannelIDs = await recorder.fetchedChannelIDs()
            XCTAssertEqual(fetchedChannelIDs, [])
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

    private func captureStandardOutput<T>(
        _ operation: () async throws -> T
    ) async throws -> (T, String) {
        let pipe = Pipe()
        let originalStdout = dup(STDOUT_FILENO)
        fflush(stdout)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)

        func restore() {
            fflush(stdout)
            dup2(originalStdout, STDOUT_FILENO)
            close(originalStdout)
            pipe.fileHandleForWriting.closeFile()
        }

        do {
            let value = try await operation()
            restore()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return (value, String(decoding: data, as: UTF8.self))
        } catch {
            restore()
            throw error
        }
    }

    private static func unwrappedLogOutput(_ output: String) -> String {
        output
            .split(separator: "\n")
            .map { line -> String in
                guard
                    let data = line.data(using: .utf8),
                    let object = try? JSONSerialization.jsonObject(with: data),
                    let dictionary = object as? [String: Any],
                    let wrappedLine = dictionary["line"] as? String
                else {
                    return String(line)
                }

                return wrappedLine
            }
            .joined(separator: "\n")
    }
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

    func snapshot() -> (
        checkCount: Int,
        fetchCount: Int,
        manualTaskObservedDuringCheck: Bool,
        validationTokens: [String?]
    ) {
        (
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

    func fetchedChannelIDs() -> [String] {
        channelIDs
    }

    func record(_ channelID: String) {
        channelIDs.append(channelID)
    }
}
