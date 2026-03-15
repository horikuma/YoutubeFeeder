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
          "formatVersion": 1,
          "exportedAt": "2026-03-15T01:23:45Z",
          "customChannels": [
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

        XCTAssertEqual(document.formatVersion, 1)
        XCTAssertEqual(document.customChannels, [RegisteredChannelRecord(channelID: "UC123", addedAt: ISO8601DateFormatter().date(from: "2026-03-14T12:00:00Z"))])
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
            document.customChannels,
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
}
