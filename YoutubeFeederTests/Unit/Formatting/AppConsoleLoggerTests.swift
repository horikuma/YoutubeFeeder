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
        XCTAssertTrue(line.contains(#"trace_id=""#))
        XCTAssertTrue(line.contains(#"channels="2""#))
        XCTAssertTrue(line.contains(#"message="開始""#))
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
        XCTAssertTrue(line.contains(#"message="完了""#))
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
}
