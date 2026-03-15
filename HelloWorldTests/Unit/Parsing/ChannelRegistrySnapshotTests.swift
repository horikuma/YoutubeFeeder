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
}
