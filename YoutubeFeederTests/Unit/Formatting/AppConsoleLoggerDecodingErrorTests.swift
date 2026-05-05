import Foundation
import XCTest
@testable import YoutubeFeeder

private struct AppConsoleLoggerDecodingErrorExampleItem: Decodable {
    let title: String
}

final class AppConsoleLoggerDecodingErrorTests: LoggedTestCase {
    func testErrorSummaryIncludesDecodingPathForMissingKey() throws {
        struct Example: Decodable {
            let items: [AppConsoleLoggerDecodingErrorExampleItem]
        }

        let json = Data(#"{"items":[{}]}"#.utf8)

        do {
            _ = try JSONDecoder().decode(Example.self, from: json)
            XCTFail("Expected decoding to fail")
        } catch {
            XCTAssertEqual(
                AppConsoleLogger.errorSummary(error, limit: 120),
                "keyNotFound path=items.[0].title"
            )
        }
    }
}
