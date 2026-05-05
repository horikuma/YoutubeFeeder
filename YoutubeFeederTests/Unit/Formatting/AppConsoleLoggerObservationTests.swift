import XCTest
@testable import YoutubeFeeder

final class AppConsoleLoggerObservationTests: LoggedTestCase {
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

#if targetEnvironment(macCatalyst)
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
#endif

    func testErrorSummaryIncludesDecodingPathForMissingKey() throws {
        struct Example: Decodable {
            let items: [Item]

            struct Item: Decodable {
                let title: String
            }
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
