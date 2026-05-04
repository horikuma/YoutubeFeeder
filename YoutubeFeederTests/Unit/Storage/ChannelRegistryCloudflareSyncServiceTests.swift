import XCTest
@testable import YoutubeFeeder

final class ChannelRegistryCloudflareSyncServiceTests: LoggedTestCase {
    func testChannelRegistryEndpointURLAcceptsBaseURL() {
        XCTAssertEqual(
            ChannelRegistryCloudflareSyncService
                .channelRegistryEndpointURL(from: URL(string: "https://worker.example")!)
                .absoluteString,
            "https://worker.example/channel-registry"
        )
    }

    func testChannelRegistryEndpointURLDoesNotDuplicatePath() {
        XCTAssertEqual(
            ChannelRegistryCloudflareSyncService
                .channelRegistryEndpointURL(from: URL(string: "https://worker.example/channel-registry")!)
                .absoluteString,
            "https://worker.example/channel-registry"
        )
    }

    func testSyncChannelRegistryEncodesRecordsAndPostsToWorker() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let expectedSyncedAt = ISO8601DateFormatter().date(from: "2026-04-17T09:10:11Z")!
        let expectedRecords = [
            RegisteredChannelRecord(channelID: "UC111", addedAt: ISO8601DateFormatter().date(from: "2026-04-15T10:00:00Z")),
            RegisteredChannelRecord(channelID: "UC222", addedAt: ISO8601DateFormatter().date(from: "2026-04-16T11:00:00Z"))
        ]

        try await withFeedCacheBaseDirectory(temporaryRoot.appendingPathComponent("Cache", isDirectory: true)) {
            try ChannelRegistryStore.replaceChannels(expectedRecords, fileManager: fileManager)

            let recorder = RequestRecorder()
            let endpoint = URL(string: "https://worker.example")!
            let service = ChannelRegistryCloudflareSyncService(
                endpointURL: endpoint,
                dataLoader: { request in
                    await recorder.record(request)
                    return (
                        Data(),
                        HTTPURLResponse(
                            url: endpoint.appendingPathComponent("channel-registry"),
                            statusCode: 200,
                            httpVersion: nil,
                            headerFields: nil
                        )!
                    )
                },
                now: { expectedSyncedAt }
            )

            try await service.syncChannelRegistry()

            let request = await recorder.request
            XCTAssertEqual(request?.httpMethod, "PUT")
            XCTAssertEqual(request?.url?.absoluteString, "https://worker.example/channel-registry")
            XCTAssertEqual(request?.value(forHTTPHeaderField: "Content-Type"), "application/json; charset=utf-8")
            XCTAssertEqual(
                String(data: request?.httpBody ?? Data(), encoding: .utf8),
                #"{"channels":[{"addedAt":"2026-04-15T10:00:00Z","channelID":"UC111"},{"addedAt":"2026-04-16T11:00:00Z","channelID":"UC222"}],"formatVersion":1,"syncedAt":"2026-04-17T09:10:11Z"}"#
            )
            XCTAssertEqual(ChannelRegistryStore.loadChannelRecords(fileManager: fileManager), expectedRecords)
        }
    }

    func testSyncChannelRegistryThrowsForHTTPFailureWithoutMutatingStore() async throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let expectedRecords = [
            RegisteredChannelRecord(channelID: "UC333", addedAt: ISO8601DateFormatter().date(from: "2026-04-15T10:00:00Z"))
        ]

        try await withFeedCacheBaseDirectory(temporaryRoot.appendingPathComponent("Cache", isDirectory: true)) {
            try ChannelRegistryStore.replaceChannels(expectedRecords, fileManager: fileManager)

            let service = ChannelRegistryCloudflareSyncService(
                endpointURL: URL(string: "https://worker.example")!,
                dataLoader: { request in
                    (
                        Data(),
                        HTTPURLResponse(
                            url: request.url ?? URL(string: "https://worker.example/channel-registry")!,
                            statusCode: 500,
                            httpVersion: nil,
                            headerFields: nil
                        )!
                    )
                },
                now: { ISO8601DateFormatter().date(from: "2026-04-17T09:10:11Z")! }
            )

            do {
                try await service.syncChannelRegistry()
                XCTFail("Expected syncChannelRegistry() to throw")
            } catch {
                XCTAssertEqual(error as? ChannelRegistryCloudflareSyncError, .httpError(statusCode: 500))
            }
            XCTAssertEqual(ChannelRegistryStore.loadChannelRecords(fileManager: fileManager), expectedRecords)
        }
    }

    private func withFeedCacheBaseDirectory<T>(_ url: URL, operation: () async throws -> T) async rethrows -> T {
        let key = "YOUTUBEFEEDER_FEEDCACHE_BASE_DIR"
        let previousValue = ProcessInfo.processInfo.environment[key]
        setenv(key, url.path, 1)
        defer {
            FeedCacheSQLiteDatabase.resetShared()
            if let previousValue {
                setenv(key, previousValue, 1)
            } else {
                unsetenv(key)
            }
        }
        return try await operation()
    }
}

actor RequestRecorder {
    private(set) var request: URLRequest?

    func record(_ request: URLRequest) {
        self.request = request
    }
}
