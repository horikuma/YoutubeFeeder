import Foundation
import XCTest
@testable import YoutubeFeeder

final class AppConsoleLoggerDiagnosticsTests: LoggedTestCase {
    func testSanitizedKeywordCollapsesWhitespaceAndTruncates() {
        let keyword = "  swift   ui   remote   search   diagnostics   keyword  "

        XCTAssertEqual(
            AppConsoleLogger.sanitizedKeyword(keyword, limit: 32),
            "swift ui remote search diagno..."
        )
    }

    func testResponsePreviewCondensesNewlinesAndTruncates() {
        let data = Data("""
        {
          "error": {
            "message": "quota exceeded for today"
          }
        }
        """.utf8)

        XCTAssertEqual(
            AppConsoleLogger.responsePreview(data, limit: 36),
            #"{"error": {"message": "quota exce..."#
        )
    }

    func testTraceIDGeneratesUUIDFormattedString() {
        let traceID = AppConsoleLogger.traceID()

        XCTAssertEqual(UUID(uuidString: traceID)?.uuidString, traceID)
    }

    func testTraceStartTimesCanBeRecordedReadAndRemoved() {
        let traceID = AppConsoleLogger.traceID()
        let startedAt = ISO8601DateFormatter().date(from: "2026-04-23T11:13:23Z")!

        AppConsoleLogger.recordTraceStart(traceID, startedAt: startedAt)

        XCTAssertEqual(AppConsoleLogger.traceStartTime(for: traceID), startedAt)
        XCTAssertEqual(AppConsoleLogger.removeTraceStartTime(for: traceID), startedAt)
        XCTAssertNil(AppConsoleLogger.traceStartTime(for: traceID))
    }

    @MainActor
    func testStartupDiagnosticsEmitsStartupProfileLog() throws {
        let diagnostics = StartupDiagnostics()
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let logFileURL = temporaryRoot.appendingPathComponent("runtime.log")
        let appLaunchedAt = ISO8601DateFormatter().date(from: "2026-04-23T11:00:00Z")!
        let splashShownAt = ISO8601DateFormatter().date(from: "2026-04-23T11:00:01Z")!

        let output = try captureStandardOutput {
            try withRuntimeLogFile(logFileURL) {
                diagnostics.mark("appLaunched", at: appLaunchedAt)
                diagnostics.mark("splashShown", at: splashShownAt)
            }
        }

        XCTAssertTrue(output.contains("startup_profile"))
        XCTAssertTrue(output.contains(#"T0=""#))
        XCTAssertTrue(output.contains(#"T1="2026-04-23T11:00:00.000Z""#))
        XCTAssertTrue(output.contains(#"T2="2026-04-23T11:00:01.000Z""#))
    }

    @MainActor
    func testStartupDiagnosticsExposesT0ProcessStartTime() {
        let diagnostics = StartupDiagnostics()

        XCTAssertLessThanOrEqual(diagnostics.startupProfileT0, Date())
    }

    @MainActor
    func testStartupDiagnosticsExposesT1AppInitializationTime() {
        let diagnostics = StartupDiagnostics()
        let appLaunchedAt = ISO8601DateFormatter().date(from: "2026-04-23T11:00:00Z")!

        diagnostics.mark("appLaunched", at: appLaunchedAt)

        XCTAssertEqual(diagnostics.startupProfileT1, appLaunchedAt)
    }

    @MainActor
    func testStartupDiagnosticsExposesT2InitialDisplayTime() {
        let diagnostics = StartupDiagnostics()
        let appLaunchedAt = ISO8601DateFormatter().date(from: "2026-04-23T11:00:00Z")!
        let splashShownAt = ISO8601DateFormatter().date(from: "2026-04-23T11:00:01Z")!

        diagnostics.mark("appLaunched", at: appLaunchedAt)
        diagnostics.mark("splashShown", at: splashShownAt)

        XCTAssertEqual(diagnostics.startupProfileT2, splashShownAt)
    }

    func testTraceEventAllowsOnlyStateChangeAnomalyAndImportantEvents() throws {
        let logger = AppConsoleLogger(scope: "event.guard")
        let allowedTraceID = AppConsoleLogger.traceID()
        let blockedTraceID = AppConsoleLogger.traceID()

        let allowedOutput = try captureStandardOutput {
            logger.traceEvent(
                "state_change_selected",
                traceID: allowedTraceID,
                message: "選択",
                metadata: ["reason": "user_action"]
            )
        }
        let blockedOutput = try captureStandardOutput {
            logger.traceEvent(
                "diagnostic_snapshot",
                traceID: blockedTraceID,
                message: "観測",
                metadata: ["reason": "debug"]
            )
        }

        XCTAssertTrue(allowedOutput.contains("state_change_selected"))
        XCTAssertTrue(allowedOutput.contains(allowedTraceID))
        XCTAssertFalse(blockedOutput.contains("diagnostic_snapshot"))
        XCTAssertFalse(blockedOutput.contains(blockedTraceID))
    }
}
