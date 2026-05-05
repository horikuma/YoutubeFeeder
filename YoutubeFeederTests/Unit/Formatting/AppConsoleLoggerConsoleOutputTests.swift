import Foundation
import XCTest
@testable import YoutubeFeeder

final class AppConsoleLoggerConsoleOutputTests: LoggedTestCase {
    func testConsoleOutputWritesLineToStandardOutput() throws {
        let renderedLine = "[YoutubeFeeder] 2026-04-18T00:00:00.000Z INFO cloudflare.sync.console_written"

        let output = try captureStandardOutput {
            AppConsoleLogger.writeConsoleLine(renderedLine, level: .info)
        }

        XCTAssertTrue(output.contains(renderedLine))
    }

    func testWarningConsoleOutputWritesLineToStandardError() throws {
        let renderedLine = "[YoutubeFeeder] 2026-04-18T00:00:00.000Z WARNING cloudflare.sync.console_written"

        let output = try captureStandardError {
            AppConsoleLogger.writeConsoleLine(renderedLine, level: .warning)
        }

        XCTAssertTrue(output.contains(renderedLine))
    }
}
