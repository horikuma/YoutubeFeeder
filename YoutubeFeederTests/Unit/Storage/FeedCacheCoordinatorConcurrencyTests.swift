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
}
