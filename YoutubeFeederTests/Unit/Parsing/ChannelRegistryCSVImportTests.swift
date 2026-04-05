import XCTest
@testable import YoutubeFeeder

final class ChannelRegistryCSVImportTests: LoggedTestCase {
    func testParserExtractsChannelIDsFromYouTubeExportCSV() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("llm-temp", isDirectory: true)
            .appendingPathComponent("登録チャンネル.csv")
        let data = try Data(contentsOf: url)

        let rows = try ChannelRegistryCSVImportParser.parse(data: data)

        XCTAssertEqual(rows.count, 300)
        XCTAssertEqual(rows.first?.channelID, "UC--oTE32O37NvGS_4rS2cRg")
        XCTAssertEqual(rows.first?.channelURL, "http://www.youtube.com/channel/UC--oTE32O37NvGS_4rS2cRg")
        XCTAssertEqual(rows.first?.channelTitle, "アットおどろく:マルベロス")
    }

    func testParserRejectsUnexpectedHeader() throws {
        let data = """
        channel_id,url,title
        UC123,https://www.youtube.com/channel/UC123,Example
        """.data(using: .utf8)!

        XCTAssertThrowsError(try ChannelRegistryCSVImportParser.parse(data: data)) { error in
            XCTAssertEqual(error as? ChannelRegistryCSVImportError, .invalidHeader)
        }
    }

    func testParserRejectsMissingChannelID() throws {
        let data = """
        チャンネル ID,チャンネルの URL,チャンネルのタイトル
        ,https://www.youtube.com/channel/UC123,Example
        """.data(using: .utf8)!

        XCTAssertThrowsError(try ChannelRegistryCSVImportParser.parse(data: data)) { error in
            XCTAssertEqual(error as? ChannelRegistryCSVImportError, .missingChannelID(rowNumber: 2))
        }
    }

    func testParserRejectsEmptyFile() throws {
        XCTAssertThrowsError(try ChannelRegistryCSVImportParser.parse(data: Data())) { error in
            XCTAssertEqual(error as? ChannelRegistryCSVImportError, .emptyFile)
        }
    }

    func testParserRejectsInvalidUTF8() throws {
        let data = Data([0xFF, 0xFE, 0x00])

        XCTAssertThrowsError(try ChannelRegistryCSVImportParser.parse(data: data)) { error in
            XCTAssertEqual(error as? ChannelRegistryCSVImportError, .invalidEncoding)
        }
    }
}
