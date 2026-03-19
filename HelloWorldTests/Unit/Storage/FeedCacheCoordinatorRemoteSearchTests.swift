import XCTest
@testable import HelloWorld

@MainActor
final class FeedCacheCoordinatorRemoteSearchTests: LoggedTestCase {
    func testForceRefreshPersistsRemoteSearchResultToCache() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        try await withEnvironment([
            "HELLOWORLD_FEEDCACHE_BASE_DIR": temporaryRoot.appendingPathComponent("Cache", isDirectory: true).path,
            "HELLOWORLD_UI_TEST_MODE": "1"
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
