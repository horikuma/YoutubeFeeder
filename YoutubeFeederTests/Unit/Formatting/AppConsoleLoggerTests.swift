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
            #"[YoutubeFeeder] 2026-04-18T00:00:00.000Z INFO cloudflare.sync.http_response_received endpoint_path="/channel-registry" status="200" message="保存完了""#
        )
    }

    func testInfoRenderLineOmitsBracketedListLikeMetadataValues() {
        let line = AppConsoleLogger.renderLine(
            timestamp: "2026-04-18T00:00:00.000Z",
            level: .info,
            scope: "cloudflare.sync",
            event: "http_response_received",
            message: nil,
            metadata: [
                "items": "[a, b]",
                "status": "200"
            ]
        )

        XCTAssertTrue(line.contains(#"status="200""#))
        XCTAssertFalse(line.contains(#"items="[a, b]""#))
    }

    func testDebugRenderLineKeepsBracketedListLikeMetadataValues() {
        let line = AppConsoleLogger.renderLine(
            timestamp: "2026-04-18T00:00:00.000Z",
            level: .debug,
            scope: "cloudflare.sync",
            event: "http_response_received",
            message: nil,
            metadata: [
                "items": "[a, b]",
                "status": "200"
            ]
        )

        XCTAssertTrue(line.contains(#"status="200""#))
        XCTAssertTrue(line.contains(#"items="[a, b]""#))
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

        let output = try String(contentsOf: logFileURL, encoding: .utf8)
        XCTAssertTrue(output.contains(renderedLine))
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

        let lines = try String(contentsOf: logFileURL, encoding: .utf8)
            .split(separator: "\n")
            .map(String.init)
        let line = try XCTUnwrap(lines.last)
        XCTAssertTrue(line.hasPrefix("[YoutubeFeeder] "))
        XCTAssertTrue(line.contains(" INFO cloudflare.sync.contract_boundary "))
        XCTAssertTrue(line.contains(#"channels="2""#))
        XCTAssertTrue(line.contains(#"status="200""#))
        XCTAssertTrue(line.contains(#"message="同期境界""#))
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

        let lines = try String(contentsOf: logFileURL, encoding: .utf8)
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

        let lines = try String(contentsOf: logFileURL, encoding: .utf8)
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
                "contract_boundary_event",
                traceID: traceID,
                message: "観測",
                metadata: [
                    "channels": "2"
                ]
            )
        }

        XCTAssertEqual(AppConsoleLogger.traceStartTime(for: traceID), startedAt)

        let lines = try String(contentsOf: logFileURL, encoding: .utf8)
            .split(separator: "\n")
            .map(String.init)
        let line = try XCTUnwrap(lines.last)
        XCTAssertTrue(line.contains(" INFO cloudflare.sync.contract_boundary_event "))
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
        return String(decoding: data, as: UTF8.self)
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
        return String(decoding: data, as: UTF8.self)
    }
}
