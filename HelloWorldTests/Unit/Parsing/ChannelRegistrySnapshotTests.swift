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
            snapshot.customChannels,
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

    func testExportIncludesBundledAndCustomChannels() throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let bundle = try makeBundle(
            named: "ExportChannels",
            channelsContents: """
            UC111
            UC222
            """
        )
        defer { try? fileManager.removeItem(at: bundle.bundleURL) }

        try withFeedCacheBaseDirectory(temporaryRoot.appendingPathComponent("Cache", isDirectory: true)) {
            try ChannelRegistryStore.replaceCustomChannels(
                [RegisteredChannelRecord(channelID: "UC333", addedAt: ISO8601DateFormatter().date(from: "2026-03-14T12:00:00Z"))],
                fileManager: fileManager
            )

            let result = try ChannelRegistryTransferStore.export(
                bundle: bundle,
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
                    RegisteredChannelRecord(channelID: "UC222", addedAt: nil),
                    RegisteredChannelRecord(channelID: "UC333", addedAt: ISO8601DateFormatter().date(from: "2026-03-14T12:00:00Z")),
                ]
            )
        }
    }

    func testImportKeepsAllChannelsAvailableWithoutBundledList() throws {
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

        let emptyBundle = try makeBundle(named: "EmptyChannels", channelsContents: nil)
        defer { try? fileManager.removeItem(at: emptyBundle.bundleURL) }

        try withFeedCacheBaseDirectory(temporaryRoot.appendingPathComponent("Cache", isDirectory: true)) {
            _ = try ChannelRegistryTransferStore.import(
                fileManager: fileManager,
                backend: .localDocuments,
                containerURL: temporaryRoot
            )

            XCTAssertEqual(
                ChannelRegistryStore.loadAllChannels(bundle: emptyBundle, fileManager: fileManager),
                [
                    RegisteredChannel(channelID: "UC111", addedAt: nil),
                    RegisteredChannel(channelID: "UC222", addedAt: ISO8601DateFormatter().date(from: "2026-03-14T12:00:00Z")),
                ]
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

    private func makeBundle(named name: String, channelsContents: String?) throws -> Bundle {
        let fileManager = FileManager.default
        let bundleURL = fileManager.temporaryDirectory.appendingPathComponent("\(name).bundle", isDirectory: true)
        let resourcesURL = bundleURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        try fileManager.createDirectory(at: resourcesURL, withIntermediateDirectories: true)

        let infoPlist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>test.\(name)</string>
            <key>CFBundleName</key>
            <string>\(name)</string>
            <key>CFBundlePackageType</key>
            <string>BNDL</string>
            <key>CFBundleVersion</key>
            <string>1</string>
        </dict>
        </plist>
        """
        try infoPlist.write(to: bundleURL.appendingPathComponent("Contents/Info.plist"), atomically: true, encoding: .utf8)

        if let channelsContents {
            try channelsContents.write(to: resourcesURL.appendingPathComponent("Channels.txt"), atomically: true, encoding: .utf8)
        }

        guard let bundle = Bundle(url: bundleURL) else {
            XCTFail("Failed to create test bundle")
            throw NSError(domain: "ChannelRegistrySnapshotTests", code: 1)
        }

        return bundle
    }
}
