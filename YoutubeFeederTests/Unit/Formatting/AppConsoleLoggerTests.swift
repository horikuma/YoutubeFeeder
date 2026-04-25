import Darwin
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
        let line = Self.unwrappedLogOutput(AppConsoleLogger.renderLine(
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
        let line = Self.unwrappedLogOutput(AppConsoleLogger.renderLine(
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
        let line = Self.unwrappedLogOutput(AppConsoleLogger.renderLine(
            timestamp: "2026-04-23T20:13:23.000+09:00",
            level: .info,
            scope: "app.lifecycle",
            event: "app_launch",
            message: nil,
            metadata: [
                "app_version": "1.0",
                "build_version": "3",
                "launch_mode": "ui_test_live",
                "runtime_log_file": "youtubefeeder-runtime-20260423-201323-123-p1234.log"
            ]
        ))

        XCTAssertTrue(line.contains(#"app_version="1.0""#))
        XCTAssertTrue(line.contains(#"build_version="3""#))
        XCTAssertTrue(line.contains(#"launch_mode="ui_test_live""#))
        XCTAssertTrue(line.contains(#"runtime_log_file="youtubefeeder-runtime-20260423-201323-123-p1234.log""#))
    }

    func testLaunchRuntimeLogFileNameIncludesLaunchSpecificComponents() {
        let date = ISO8601DateFormatter().date(from: "2026-04-23T11:13:23Z")!

        XCTAssertEqual(
            AppConsoleLogger.launchRuntimeLogFileName(date: date, processIdentifier: 1234),
            "youtubefeeder-runtime-20260423-201323-000-pid1234.log"
        )
    }

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

    #if targetEnvironment(macCatalyst)
    func testFileOutputAppendsLineToRuntimeLogFile() throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let logFileURL = temporaryRoot.appendingPathComponent("runtime.log")
        let renderedLine = "[YoutubeFeeder] 2026-04-18T00:00:00.000Z INFO cloudflare.sync.file_written"

        try withRuntimeLogFile(logFileURL) {
            AppConsoleLogger.writeFileLine(renderedLine)
        }

        let output = Self.unwrappedLogOutput(try String(contentsOf: logFileURL, encoding: .utf8))
        XCTAssertTrue(output.contains(renderedLine))
    }

    func testPrepareRuntimeLogFileForLaunchTruncatesExistingRuntimeLogFile() throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let logFileURL = temporaryRoot.appendingPathComponent("runtime.log")
        try "previous line\n".write(to: logFileURL, atomically: true, encoding: .utf8)

        AppConsoleLogger.prepareRuntimeLogFileForLaunch(runtimeLogFileURL: logFileURL)

        XCTAssertEqual(try String(contentsOf: logFileURL, encoding: .utf8), "")
    }
    #endif

#if targetEnvironment(macCatalyst)
    func testMacRuntimeLogFileURLUsesProjectLogsDirectory() throws {
        let sourceFilePath = "/Repo/YoutubeFeeder/App/AppConsoleLogger.swift"

        let url = try XCTUnwrap(AppConsoleLogger.runtimeLogFileURL(sourceFilePath: sourceFilePath))

        XCTAssertEqual(url.path, "/Repo/logs/youtubefeeder-runtime.log")
    }

    func testMacLoggerWritesSameRenderedLineToRuntimeLogFile() throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let logFileURL = temporaryRoot.appendingPathComponent("runtime.log")
        try withRuntimeLogFile(logFileURL) {
            AppConsoleLogger.cloudflareSync.info(
                "contract_boundary",
                message: "同期境界",
                metadata: [
                    "status": "200",
                    "channels": "2"
                ]
            )
        }

        let rawOutput = try String(contentsOf: logFileURL, encoding: .utf8)
        let lines = rawOutput
            .split(separator: "\n")
            .map(String.init)
        let rawLine = try XCTUnwrap(lines.last)
        XCTAssertTrue(rawLine.hasPrefix(#"{"line":"[YoutubeFeeder] "#))

        let plainLine = try XCTUnwrap(
            Self.unwrappedLogOutput(rawOutput)
                .split(separator: "\n")
                .map(String.init)
                .last
        )
        XCTAssertTrue(plainLine.contains(" INFO cloudflare.sync.contract_boundary "))
        XCTAssertTrue(plainLine.contains(#"channels="2""#))
        XCTAssertTrue(plainLine.contains(#"status="200""#))
        XCTAssertTrue(plainLine.contains(#"message="同期境界""#))
    }

    func testDebugLogsAreSuppressedAtInfoMinimumLevel() throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let logFileURL = temporaryRoot.appendingPathComponent("runtime.log")
        try withRuntimeLogFile(logFileURL) {
            AppConsoleLogger.cloudflareSync.debug(
                "suppressed_debug",
                message: "抑制確認",
                metadata: [
                    "channels": "2"
                ]
            )
        }

        XCTAssertFalse(fileManager.fileExists(atPath: logFileURL.path))
    }
#endif

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

    #if targetEnvironment(macCatalyst)
    func testScopeInvocationCountsCanBeRecordedReadAndRemoved() throws {
        let logger = AppConsoleLogger(scope: "count.test")
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }
        defer { _ = AppConsoleLogger.removeScopeInvocationCount(for: "count.test") }

        let logFileURL = temporaryRoot.appendingPathComponent("runtime.log")
        try withRuntimeLogFile(logFileURL) {
            logger.info("first")
            logger.info("second")
        }

        XCTAssertEqual(AppConsoleLogger.scopeInvocationCount(for: "count.test"), 2)
        XCTAssertEqual(AppConsoleLogger.removeScopeInvocationCount(for: "count.test"), 2)
        XCTAssertEqual(AppConsoleLogger.scopeInvocationCount(for: "count.test"), 0)
    }
    #endif

    func testScopeInvocationWindowSecondsIsFixedValue() {
        XCTAssertEqual(AppConsoleLogger.scopeInvocationWindowSeconds, 1)
    }

    func testScopeInvocationThresholdCountIsFixedValue() {
        XCTAssertEqual(AppConsoleLogger.scopeInvocationThresholdCount, 50)
    }

    func testScopeInvocationThresholdExceededDetectsHighFrequencyCalls() {
        let scope = "count.threshold.\(UUID().uuidString)"
        defer { _ = AppConsoleLogger.removeScopeInvocationCount(for: scope) }

        AppConsoleLogger.recordScopeInvocation(for: scope)
        AppConsoleLogger.recordScopeInvocation(for: scope)

        XCTAssertEqual(
            AppConsoleLogger.scopeInvocationThresholdExceeded(for: scope, limit: 1),
            .exceeded(scope: scope, count: 2, limit: 1)
        )
        XCTAssertNil(AppConsoleLogger.scopeInvocationThresholdExceeded(for: scope, limit: 2))
    }

    func testScopeInvocationCountsResetAfterOneSecondWindow() {
        let scope = "count.reset.\(UUID().uuidString)"
        defer { _ = AppConsoleLogger.removeScopeInvocationCount(for: scope) }

        let base = ISO8601DateFormatter().date(from: "2026-04-23T11:13:23Z")!

        AppConsoleLogger.recordScopeInvocation(for: scope, at: base)
        AppConsoleLogger.recordScopeInvocation(for: scope, at: base.addingTimeInterval(0.5))
        XCTAssertEqual(AppConsoleLogger.scopeInvocationCount(for: scope), 2)

        AppConsoleLogger.recordScopeInvocation(for: scope, at: base.addingTimeInterval(1.0))
        XCTAssertEqual(AppConsoleLogger.scopeInvocationCount(for: scope), 1)
    }

    func testScopeInvocationThresholdExceededWarningWritesWarningLog() throws {
        let scope = "count.warning.\(UUID().uuidString)"
        defer { _ = AppConsoleLogger.removeScopeInvocationCount(for: scope) }

        AppConsoleLogger.recordScopeInvocation(for: scope)
        AppConsoleLogger.recordScopeInvocation(for: scope)

        let output = try captureStandardError {
            _ = AppConsoleLogger.scopeInvocationThresholdExceededWarning(for: scope, limit: 1)
        }

        XCTAssertTrue(output.contains(" WARNING "))
        XCTAssertTrue(output.contains("scope_invocation_threshold_exceeded"))
        XCTAssertTrue(output.contains(scope))
        XCTAssertTrue(output.contains(#"count="2""#))
        XCTAssertTrue(output.contains(#"limit="1""#))
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

        let lines = Self.unwrappedLogOutput(try String(contentsOf: logFileURL, encoding: .utf8))
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

        let lines = Self.unwrappedLogOutput(try String(contentsOf: logFileURL, encoding: .utf8))
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

        let lines = Self.unwrappedLogOutput(try String(contentsOf: logFileURL, encoding: .utf8))
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

#if targetEnvironment(macCatalyst)
    private func withRuntimeLogFile(_ url: URL, operation: () throws -> Void) rethrows {
        let key = "YOUTUBEFEEDER_RUNTIME_LOG_FILE"
        let previousValue = ProcessInfo.processInfo.environment[key]
        setenv(key, url.path, 1)
        defer {
            if let previousValue {
                setenv(key, previousValue, 1)
            } else {
                unsetenv(key)
            }
        }
        try operation()
    }
#endif

    private func captureStandardOutput(_ operation: () throws -> Void) rethrows -> String {
        let pipe = Pipe()
        let originalStdout = dup(STDOUT_FILENO)
        fflush(stdout)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        try operation()

        fflush(stdout)
        dup2(originalStdout, STDOUT_FILENO)
        close(originalStdout)
        pipe.fileHandleForWriting.closeFile()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return Self.unwrappedLogOutput(String(decoding: data, as: UTF8.self))
    }

    private func captureStandardError(_ operation: () throws -> Void) rethrows -> String {
        let pipe = Pipe()
        let originalStderr = dup(STDERR_FILENO)
        fflush(stderr)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)

        try operation()

        fflush(stderr)
        dup2(originalStderr, STDERR_FILENO)
        close(originalStderr)
        pipe.fileHandleForWriting.closeFile()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return Self.unwrappedLogOutput(String(decoding: data, as: UTF8.self))
    }

    private static func unwrappedLogOutput(_ output: String) -> String {
        output
            .split(separator: "\n")
            .map { line -> String in
                guard
                    let data = line.data(using: .utf8),
                    let object = try? JSONSerialization.jsonObject(with: data),
                    let dictionary = object as? [String: Any],
                    let wrappedLine = dictionary["line"] as? String
                else {
                    return String(line)
                }

                return wrappedLine
            }
            .joined(separator: "\n")
    }
}
