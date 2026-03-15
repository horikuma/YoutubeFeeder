import XCTest
@testable import HelloWorld

final class RemoteVideoSearchCacheStoreTests: XCTestCase {
    func testRemoteSearchCacheStatusReflectsFreshnessWindow() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        try await withFeedCacheBaseDirectory(temporaryRoot.appendingPathComponent("Cache", isDirectory: true)) {
            let store = RemoteVideoSearchCacheStore()
            let fetchedAt = ISO8601DateFormatter().date(from: "2026-03-15T03:00:00Z")!
            await store.save(
                keyword: "ゆっくり実況",
                videos: [
                    CachedVideo(
                        id: "video-1",
                        channelID: "UC111",
                        channelTitle: "Channel One",
                        title: "ゆっくり実況 one",
                        publishedAt: fetchedAt,
                        videoURL: URL(string: "https://www.youtube.com/watch?v=video-1"),
                        thumbnailRemoteURL: nil,
                        thumbnailLocalFilename: nil,
                        fetchedAt: fetchedAt,
                        searchableText: "ゆっくり実況 one"
                    )
                ],
                totalCount: 24,
                fetchedAt: fetchedAt
            )

            let freshStatus = await store.status(
                keyword: "ゆっくり実況",
                ttl: 12 * 60 * 60,
                now: fetchedAt.addingTimeInterval(60)
            )
            XCTAssertTrue(freshStatus.exists)
            XCTAssertTrue(freshStatus.isFresh)
            XCTAssertEqual(freshStatus.totalCount, 24)

            let staleStatus = await store.status(
                keyword: "ゆっくり実況",
                ttl: 12 * 60 * 60,
                now: fetchedAt.addingTimeInterval(13 * 60 * 60)
            )
            XCTAssertTrue(staleStatus.exists)
            XCTAssertFalse(staleStatus.isFresh)
            XCTAssertEqual(staleStatus.label, "期限切れ")
        }
    }

    private func withFeedCacheBaseDirectory<T>(_ url: URL, operation: () async throws -> T) async throws -> T {
        let key = "HELLOWORLD_FEEDCACHE_BASE_DIR"
        let previousValue = ProcessInfo.processInfo.environment[key]
        setenv(key, url.path, 1)
        defer {
            if let previousValue {
                setenv(key, previousValue, 1)
            } else {
                unsetenv(key)
            }
        }
        return try await operation()
    }
}
