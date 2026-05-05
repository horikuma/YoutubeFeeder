import Foundation
import XCTest
@testable import YoutubeFeeder

final class AppConsoleLoggerTraceLifecycleTests: LoggedTestCase {
    func testTraceLifecycleMismatchDetectionFindsOrphanStartsAndMissingStarts() {
        let traceID = AppConsoleLogger.traceID()
        let startedAt = ISO8601DateFormatter().date(from: "2026-04-23T11:13:23Z")!

        AppConsoleLogger.recordTraceStart(traceID, startedAt: startedAt)

        guard case let .unfinishedStarts(traceIDs)? = AppConsoleLogger.traceStartMismatch() else {
            XCTFail("Expected unfinished starts to be reported")
            return
        }
        XCTAssertTrue(traceIDs.contains(traceID))
        XCTAssertEqual(
            AppConsoleLogger.traceEndMismatch(for: traceID, startedAt: nil),
            .missingStart(traceID: traceID)
        )
    }

    func testTraceEndMismatchWarningWritesWarningLog() throws {
        let traceID = AppConsoleLogger.traceID()

        let output = try captureStandardError {
            _ = AppConsoleLogger.traceEndMismatchWarning(for: traceID, startedAt: nil)
        }

        XCTAssertTrue(output.contains(" WARNING "))
        XCTAssertTrue(output.contains("trace_lifecycle_mismatch"))
        XCTAssertTrue(output.contains(traceID))
    }

    func testTraceStartMismatchWarningWritesWarningLog() throws {
        let traceID = AppConsoleLogger.traceID()
        let startedAt = ISO8601DateFormatter().date(from: "2026-04-23T11:13:23Z")!

        AppConsoleLogger.recordTraceStart(traceID, startedAt: startedAt)
        defer { _ = AppConsoleLogger.removeTraceStartTime(for: traceID) }

        let output = try captureStandardError {
            _ = AppConsoleLogger.traceStartMismatchWarning()
        }

        XCTAssertTrue(output.contains(" WARNING "))
        XCTAssertTrue(output.contains("trace_lifecycle_mismatch"))
        XCTAssertTrue(output.contains(traceID))
    }
}

