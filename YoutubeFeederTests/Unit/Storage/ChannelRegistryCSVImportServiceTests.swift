import XCTest
@testable import YoutubeFeeder

final class ChannelRegistryCSVImportServiceTests: LoggedTestCase {
    func testImportAppendsOnlyNewChannelIDsAndReportsCounts() throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let csv = """
        チャンネル ID,チャンネルの URL,チャンネルのタイトル
        UC111,https://www.youtube.com/channel/UC111,One
        UC222,https://www.youtube.com/channel/UC222,Two
        UC111,https://www.youtube.com/channel/UC111,One duplicate
        """
        let sourceURL = temporaryRoot.appendingPathComponent("channels.csv")
        try csv.data(using: .utf8)!.write(to: sourceURL, options: .atomic)

        try withFeedCacheBaseDirectory(temporaryRoot.appendingPathComponent("Cache", isDirectory: true)) {
            try ChannelRegistryStore.replaceChannels(
                [RegisteredChannelRecord(channelID: "UC111", addedAt: nil)],
                fileManager: fileManager
            )

            let result = try ChannelRegistryCSVImportService.importChannels(
                data: try Data(contentsOf: sourceURL),
                fileURL: sourceURL,
                fileManager: fileManager
            )

            XCTAssertEqual(result.importedChannelIDs, ["UC222"])
            XCTAssertEqual(result.totalRowCount, 3)
            XCTAssertEqual(result.importedCount, 1)
            XCTAssertEqual(result.alreadyRegisteredCount, 2)
            XCTAssertEqual(ChannelRegistryStore.loadAllChannelIDs(fileManager: fileManager), ["UC111", "UC222"])
        }
    }

    private func withFeedCacheBaseDirectory<T>(_ url: URL, operation: () throws -> T) throws -> T {
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
        return try operation()
    }
}
