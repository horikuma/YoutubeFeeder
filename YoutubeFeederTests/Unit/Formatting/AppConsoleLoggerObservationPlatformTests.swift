import XCTest
@testable import YoutubeFeeder

#if targetEnvironment(macCatalyst)
final class AppConsoleLoggerObservationPlatformTests: LoggedTestCase {
    func testTraceStartLogsTraceIDAndRecordsStartTime() throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let logFileURL = temporaryRoot.appendingPathComponent("runtime.log")
        var traceID: String?
        try withRuntimeLogFile(logFileURL) {
            traceID = AppConsoleLogger.cloudflareSync.traceStart(
                "contract_boundary",
                message: "開始",
                metadata: [
                    "channels": "2"
                ]
            )
        }

        let resolvedTraceID = try XCTUnwrap(traceID)
        XCTAssertNotNil(AppConsoleLogger.traceStartTime(for: resolvedTraceID))

        let lines = unwrappedLogOutput(try String(contentsOf: logFileURL, encoding: .utf8))
            .split(separator: "\n")
            .map(String.init)
        let line = try XCTUnwrap(lines.last)
        XCTAssertTrue(line.contains(" INFO cloudflare.sync.contract_boundary "))
        XCTAssertTrue(line.contains(#"channels="2""#))
        XCTAssertTrue(line.contains(#"message="開始""#))
        XCTAssertFalse(line.contains(#"trace_id=""#))
    }

    func testTraceEndLogsTraceIDAndClearsStartTime() throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let logFileURL = temporaryRoot.appendingPathComponent("runtime.log")
        let traceID = AppConsoleLogger.traceID()
        let startedAt = ISO8601DateFormatter().date(from: "2026-04-23T11:15:23Z")!
        AppConsoleLogger.recordTraceStart(traceID, startedAt: startedAt)

        var returnedStartedAt: Date?
        try withRuntimeLogFile(logFileURL) {
            returnedStartedAt = AppConsoleLogger.cloudflareSync.traceEnd(
                "contract_boundary",
                traceID: traceID,
                message: "完了",
                count: "2",
                size: "128",
                result: "success",
                metadata: [
                    "channels": "2"
                ]
            )
        }

        XCTAssertEqual(returnedStartedAt, startedAt)
        XCTAssertNil(AppConsoleLogger.traceStartTime(for: traceID))

        let lines = unwrappedLogOutput(try String(contentsOf: logFileURL, encoding: .utf8))
            .split(separator: "\n")
            .map(String.init)
        let line = try XCTUnwrap(lines.last)
        XCTAssertTrue(line.contains(" INFO cloudflare.sync.contract_boundary "))
        XCTAssertTrue(line.contains(#"trace_id=""#))
        XCTAssertTrue(line.contains(#"channels="2""#))
        XCTAssertTrue(line.contains(#"count="2""#))
        XCTAssertTrue(line.contains(#"size="128""#))
        XCTAssertTrue(line.contains(#"result="success""#))
        XCTAssertTrue(line.contains(#"duration_ms=""#))
        XCTAssertTrue(line.contains(#"message="完了""#))
    }

    func testTraceEventLogsTraceIDWithoutClearingStartTime() throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let logFileURL = temporaryRoot.appendingPathComponent("runtime.log")
        let traceID = AppConsoleLogger.traceID()
        let startedAt = ISO8601DateFormatter().date(from: "2026-04-23T11:20:23Z")!
        AppConsoleLogger.recordTraceStart(traceID, startedAt: startedAt)

        try withRuntimeLogFile(logFileURL) {
            AppConsoleLogger.cloudflareSync.traceEvent(
                "important_contract_boundary_event",
                traceID: traceID,
                message: "観測",
                metadata: [
                    "channels": "2"
                ]
            )
        }

        XCTAssertEqual(AppConsoleLogger.traceStartTime(for: traceID), startedAt)

        let lines = unwrappedLogOutput(try String(contentsOf: logFileURL, encoding: .utf8))
            .split(separator: "\n")
            .map(String.init)
        let line = try XCTUnwrap(lines.last)
        XCTAssertTrue(line.contains(" INFO cloudflare.sync.important_contract_boundary_event "))
        XCTAssertTrue(line.contains(#"trace_id=""#))
        XCTAssertTrue(line.contains(#"channels="2""#))
        XCTAssertTrue(line.contains(#"message="観測""#))
        XCTAssertFalse(line.contains(#"duration_ms=""#))
    }

    func testTraceDurationMillisecondsComputesElapsedTime() {
        let startedAt = Date(timeIntervalSince1970: 0)
        let endedAt = Date(timeIntervalSince1970: 1.25)

        XCTAssertEqual(
            AppConsoleLogger.traceDurationMilliseconds(since: startedAt, to: endedAt),
            "1250"
        )
    }

    func testScopedLoggerNamesUseLayerOperationFormat() {
        XCTAssertEqual(AppConsoleLogger.channelRegistryTransfer.scope, "channel_registry.transfer")
        XCTAssertEqual(AppConsoleLogger.homeTransfer.scope, "home.transfer")
        XCTAssertEqual(AppConsoleLogger.remoteSearchSplitLoad.scope, "remote_search.split_load")
    }
}
#endif
