import XCTest
@testable import HelloWorld

final class ChannelRegistrySnapshotTests: XCTestCase {
    func testDecodeSupportsLegacyCustomChannelIDsFormat() throws {
        let json = """
        {
          "customChannelIDs": ["UC123", "UC456"]
        }
        """.data(using: .utf8)!

        let snapshot = try JSONDecoder().decode(ChannelRegistrySnapshot.self, from: json)

        XCTAssertEqual(
            snapshot.channels,
            [
                RegisteredChannelRecord(channelID: "UC123", addedAt: nil),
                RegisteredChannelRecord(channelID: "UC456", addedAt: nil),
            ]
        )
    }

    func testTransferDocumentDecodesCurrentFormat() throws {
        let json = """
        {
          "formatVersion": 2,
          "exportedAt": "2026-03-15T01:23:45Z",
          "channels": [
            {
              "addedAt": "2026-03-14T12:00:00Z",
              "channelID": "UC123"
            }
          ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(ChannelRegistryTransferDocument.self, from: json)

        XCTAssertEqual(document.formatVersion, 2)
        XCTAssertEqual(document.channels, [RegisteredChannelRecord(channelID: "UC123", addedAt: ISO8601DateFormatter().date(from: "2026-03-14T12:00:00Z"))])
    }

    func testTransferDocumentDecodesPreviousTransferFormat() throws {
        let json = """
        {
          "formatVersion": 1,
          "exportedAt": "2026-03-15T01:23:45Z",
          "customChannels": [
            {
              "addedAt": null,
              "channelID": "UC123"
            },
            {
              "addedAt": null,
              "channelID": "UC456"
            }
          ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(ChannelRegistryTransferDocument.self, from: json)

        XCTAssertEqual(
            document.channels,
            [
                RegisteredChannelRecord(channelID: "UC123", addedAt: nil),
                RegisteredChannelRecord(channelID: "UC456", addedAt: nil),
            ]
        )
    }

    func testTransferDocumentDecodesLegacyRegistrySnapshot() throws {
        let json = """
        {
          "customChannels": [
            {
              "addedAt": null,
              "channelID": "UC123"
            },
            {
              "addedAt": null,
              "channelID": "UC456"
            }
          ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(ChannelRegistryTransferDocument.self, from: json)

        XCTAssertEqual(
            document.channels,
            [
                RegisteredChannelRecord(channelID: "UC123", addedAt: nil),
                RegisteredChannelRecord(channelID: "UC456", addedAt: nil),
            ]
        )
    }

    func testTransferStoreUsesLocalDocumentsFixedPath() {
        let rootURL = URL(fileURLWithPath: "/tmp/HelloWorldTests", isDirectory: true)
        let path = ChannelRegistryTransferStore.fixedPathDescription(
            backend: .localDocuments,
            containerURL: rootURL
        )

        XCTAssertEqual(path, "/tmp/HelloWorldTests/HelloWorld/channel-registry.json")
    }

    func testTransferRuntimeUsesOnDeviceBackupOnly() {
        XCTAssertEqual(ChannelRegistryTransferRuntime.preferredBackend, .localDocuments)
        XCTAssertEqual(ChannelRegistryTransferRuntime.availableBackends, [.localDocuments])
    }

    func testExportIncludesRegisteredChannels() throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        try withFeedCacheBaseDirectory(temporaryRoot.appendingPathComponent("Cache", isDirectory: true)) {
            try ChannelRegistryStore.replaceChannels(
                [
                    RegisteredChannelRecord(channelID: "UC111", addedAt: nil),
                    RegisteredChannelRecord(channelID: "UC222", addedAt: ISO8601DateFormatter().date(from: "2026-03-14T12:00:00Z")),
                ],
                fileManager: fileManager
            )

            let result = try ChannelRegistryTransferStore.export(
                fileManager: fileManager,
                backend: .localDocuments,
                containerURL: temporaryRoot
            )

            let data = try Data(contentsOf: result.fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let document = try decoder.decode(ChannelRegistryTransferDocument.self, from: data)

            XCTAssertEqual(
                document.channels,
                [
                    RegisteredChannelRecord(channelID: "UC111", addedAt: nil),
                    RegisteredChannelRecord(channelID: "UC222", addedAt: ISO8601DateFormatter().date(from: "2026-03-14T12:00:00Z")),
                ]
            )
        }
    }

    func testImportRestoresRegisteredChannels() throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let backupURL = temporaryRoot
            .appendingPathComponent("HelloWorld", isDirectory: true)
            .appendingPathComponent("channel-registry.json")
        try fileManager.createDirectory(at: backupURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let backup = ChannelRegistryTransferDocument(
            channels: [
                RegisteredChannelRecord(channelID: "UC111", addedAt: nil),
                RegisteredChannelRecord(channelID: "UC222", addedAt: ISO8601DateFormatter().date(from: "2026-03-14T12:00:00Z")),
            ]
        )
        try encoder.encode(backup).write(to: backupURL, options: .atomic)

        try withFeedCacheBaseDirectory(temporaryRoot.appendingPathComponent("Cache", isDirectory: true)) {
            _ = try ChannelRegistryTransferStore.import(
                fileManager: fileManager,
                backend: .localDocuments,
                containerURL: temporaryRoot
            )

            XCTAssertEqual(
                ChannelRegistryStore.loadAllChannels(fileManager: fileManager),
                [
                    RegisteredChannel(channelID: "UC111", addedAt: nil),
                    RegisteredChannel(channelID: "UC222", addedAt: ISO8601DateFormatter().date(from: "2026-03-14T12:00:00Z")),
                ]
            )
        }
    }

    func testLoadPersistedOrSeededChannelIDsSeedsFromLegacyCacheWhenRegistryIsMissing() throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        try withFeedCacheBaseDirectory(temporaryRoot.appendingPathComponent("Cache", isDirectory: true)) {
            let cacheURL = FeedCachePaths.cacheURL(fileManager: fileManager)
            let bootstrapURL = FeedCachePaths.bootstrapURL(fileManager: fileManager)
            try fileManager.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601

            let now = ISO8601DateFormatter().date(from: "2026-03-15T03:00:00Z")
            let cache = FeedCacheSnapshot(
                savedAt: now ?? .now,
                channels: [
                    CachedChannelState(
                        channelID: "UC111",
                        channelTitle: "one",
                        lastAttemptAt: now,
                        lastCheckedAt: now,
                        lastSuccessAt: now,
                        latestPublishedAt: now,
                        cachedVideoCount: 1,
                        lastError: nil,
                        etag: nil,
                        lastModified: nil
                    ),
                ],
                videos: [
                    CachedVideo(
                        id: "video-1",
                        channelID: "UC222",
                        channelTitle: "two",
                        title: "title",
                        publishedAt: now,
                        videoURL: nil,
                        thumbnailRemoteURL: nil,
                        thumbnailLocalFilename: nil,
                        fetchedAt: now ?? .now,
                        searchableText: "title"
                    ),
                ]
            )

            let bootstrap = FeedBootstrapSnapshot(
                progress: CacheProgress(
                    totalChannels: 1,
                    cachedChannels: 1,
                    cachedVideos: 1,
                    cachedThumbnails: 0,
                    currentChannelID: nil,
                    currentChannelNumber: nil,
                    lastUpdatedAt: now,
                    isRunning: false,
                    lastError: nil
                ),
                maintenanceItems: [
                    ChannelMaintenanceItem(
                        id: "UC333",
                        channelID: "UC333",
                        channelTitle: "three",
                        lastSuccessAt: now,
                        lastCheckedAt: now,
                        latestPublishedAt: now,
                        cachedVideoCount: 1,
                        lastError: nil,
                        freshness: .fresh
                    ),
                ]
            )

            try encoder.encode(cache).write(to: cacheURL, options: .atomic)
            try encoder.encode(bootstrap).write(to: bootstrapURL, options: .atomic)

            XCTAssertEqual(
                ChannelRegistryStore.loadPersistedOrSeededChannelIDs(fileManager: fileManager),
                ["UC333", "UC111", "UC222"]
            )
            XCTAssertEqual(
                ChannelRegistryStore.loadAllChannelIDs(fileManager: fileManager),
                ["UC333", "UC111", "UC222"]
            )
        }
    }

    private func withFeedCacheBaseDirectory<T>(_ url: URL, operation: () throws -> T) throws -> T {
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
        return try operation()
    }
}
