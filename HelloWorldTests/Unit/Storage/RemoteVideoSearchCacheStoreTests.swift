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
                        searchableText: "ゆっくり実況 one",
                        durationSeconds: 1_560,
                        viewCount: 12_345
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

    func testMergeKeepsExistingVideosAndAddsNewOnes() async throws {
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
                        title: "first",
                        publishedAt: fetchedAt,
                        videoURL: nil,
                        thumbnailRemoteURL: nil,
                        thumbnailLocalFilename: nil,
                        fetchedAt: fetchedAt,
                        searchableText: "first",
                        durationSeconds: 1_400,
                        viewCount: 100
                    )
                ],
                totalCount: 1,
                fetchedAt: fetchedAt
            )

            await store.merge(
                keyword: "ゆっくり実況",
                videos: [
                    CachedVideo(
                        id: "video-2",
                        channelID: "UC222",
                        channelTitle: "Channel Two",
                        title: "second",
                        publishedAt: fetchedAt.addingTimeInterval(60),
                        videoURL: nil,
                        thumbnailRemoteURL: nil,
                        thumbnailLocalFilename: nil,
                        fetchedAt: fetchedAt.addingTimeInterval(60),
                        searchableText: "second",
                        durationSeconds: 2_400,
                        viewCount: 200
                    )
                ],
                fetchedAt: fetchedAt.addingTimeInterval(60)
            )

            let entry = await store.load(keyword: "ゆっくり実況")
            XCTAssertEqual(entry?.videos.map(\.id), ["video-2", "video-1"])
            XCTAssertEqual(entry?.totalCount, 2)
        }
    }

    func testClearAllRemovesDefaultAndSanitizedSearchCacheFiles() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        try await withFeedCacheBaseDirectory(temporaryRoot.appendingPathComponent("Cache", isDirectory: true)) {
            let store = RemoteVideoSearchCacheStore()
            let fetchedAt = ISO8601DateFormatter().date(from: "2026-03-15T03:00:00Z")!

            await store.save(keyword: "ゆっくり実況", videos: [], totalCount: 93, fetchedAt: fetchedAt)
            await store.save(keyword: "test keyword", videos: [], totalCount: 12, fetchedAt: fetchedAt)

            let removedCount = await store.clearAll()
            let japaneseEntry = await store.load(keyword: "ゆっくり実況")
            let asciiEntry = await store.load(keyword: "test keyword")

            XCTAssertEqual(removedCount, 2)
            XCTAssertNil(japaneseEntry)
            XCTAssertNil(asciiEntry)
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
