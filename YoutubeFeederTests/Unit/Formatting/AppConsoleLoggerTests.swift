import Foundation
import XCTest
@testable import YoutubeFeeder

final class AppConsoleLoggerTests: LoggedTestCase {
    func testRenderLineKeepsSingleLineConsoleFormat() {
        XCTAssertEqual(
            AppConsoleLogger.renderLine(
                timestamp: "2026-04-18T00:00:00.000Z",
                level: .info,
                scope: "cloudflare.sync",
                event: "http_response_received",
                message: "保存完了",
                metadata: [
                    "status": "200",
                    "endpoint_path": "/channel-registry"
                ]
            ),
            #"{"line":"[YoutubeFeeder] 2026-04-18T00:00:00.000Z INFO cloudflare.sync.http_response_received endpoint_path=\"\/channel-registry\" status=\"200\" message=\"保存完了\""}"#
        )
    }

    func testInfoRenderLineOmitsBracketedListLikeMetadataValues() {
        let line = unwrappedLogOutput(AppConsoleLogger.renderLine(
            timestamp: "2026-04-18T00:00:00.000Z",
            level: .info,
            scope: "cloudflare.sync",
            event: "http_response_received",
            message: nil,
            metadata: [
                "items": "[a, b]",
                "status": "200"
            ]
        ))

        XCTAssertTrue(line.contains(#"status="200""#))
        XCTAssertFalse(line.contains(#"items="[a, b]""#))
    }

    func testTimestampFormattingUsesJST() {
        let date = ISO8601DateFormatter().date(from: "2026-04-23T11:13:23Z")!

        XCTAssertEqual(
            AppConsoleLogger.timestamp(for: date),
            "2026-04-23T20:13:23.000+09:00"
        )
    }

    func testDebugRenderLineKeepsBracketedListLikeMetadataValues() {
        let line = unwrappedLogOutput(AppConsoleLogger.renderLine(
            timestamp: "2026-04-18T00:00:00.000Z",
            level: .debug,
            scope: "cloudflare.sync",
            event: "http_response_received",
            message: nil,
            metadata: [
                "items": "[a, b]",
                "status": "200"
            ]
        ))

        XCTAssertTrue(line.contains(#"status="200""#))
        XCTAssertTrue(line.contains(#"items="[a, b]""#))
    }

    func testRenderLineKeepsAppLaunchMetadataReadable() {
        let line = unwrappedLogOutput(AppConsoleLogger.renderLine(
            timestamp: "2026-04-23T20:13:23.000+09:00",
            level: .info,
            scope: "app.lifecycle",
            event: "app_launch",
            message: nil,
            metadata: [
                "app_version": "1.0",
                "build_version": "3",
                "launch_mode": "ui_test_live",
                "runtime_log_file": "youtubefeeder-runtime-20260423-201323-123-p1234.log",
                "runtime_log_override_file": "none",
                "runtime_log_override_status": "none"
            ]
        ))

        XCTAssertTrue(line.contains(#"app_version="1.0""#))
        XCTAssertTrue(line.contains(#"build_version="3""#))
        XCTAssertTrue(line.contains(#"launch_mode="ui_test_live""#))
        XCTAssertTrue(line.contains(#"runtime_log_file="youtubefeeder-runtime-20260423-201323-123-p1234.log""#))
        XCTAssertTrue(line.contains(#"runtime_log_override_file="none""#))
        XCTAssertTrue(line.contains(#"runtime_log_override_status="none""#))
    }

    func testLaunchRuntimeLogFileNameIncludesLaunchSpecificComponents() {
        let date = ISO8601DateFormatter().date(from: "2026-04-23T11:13:23Z")!

        XCTAssertEqual(
            AppConsoleLogger.launchRuntimeLogFileName(date: date, processIdentifier: 1234),
            "youtubefeeder-runtime-20260423-201323-000-pid1234.log"
        )
    }
}
