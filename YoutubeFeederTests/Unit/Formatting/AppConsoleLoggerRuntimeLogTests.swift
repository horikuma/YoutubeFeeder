import Foundation
import XCTest
@testable import YoutubeFeeder

#if targetEnvironment(macCatalyst)
final class AppConsoleLoggerRuntimeLogTests: LoggedTestCase {
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

        let output = unwrappedLogOutput(try String(contentsOf: logFileURL, encoding: .utf8))
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

    func testLegacyRuntimeLogEnvironmentOverrideDoesNotReplaceLaunchSpecificLogFile() throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let launchLogFileURL = temporaryRoot.appendingPathComponent("youtubefeeder-runtime-20260423-201323-123-pid1234.log")
        let legacyLogFileURL = temporaryRoot.appendingPathComponent("youtubefeeder-runtime.log")
        let renderedLine = "[YoutubeFeeder] 2026-04-18T00:00:00.000Z INFO cloudflare.sync.file_written"

        AppConsoleLogger.prepareRuntimeLogFileForLaunch(runtimeLogFileURL: launchLogFileURL)

        try withRuntimeLogFile(legacyLogFileURL) {
            AppConsoleLogger.writeFileLine(renderedLine)
        }

        XCTAssertFalse(fileManager.fileExists(atPath: legacyLogFileURL.path))
        let output = unwrappedLogOutput(try String(contentsOf: launchLogFileURL, encoding: .utf8))
        XCTAssertTrue(output.contains(renderedLine))
    }

    func testRuntimeLogPrepareFailureIsFlushedToNextAvailableRuntimeLogFile() throws {
        let fileManager = FileManager.default
        let temporaryRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryRoot) }

        let blockedDirectoryURL = temporaryRoot.appendingPathComponent("blocked")
        try "not a directory".write(to: blockedDirectoryURL, atomically: true, encoding: .utf8)

        AppConsoleLogger.prepareRuntimeLogFileForLaunch(
            runtimeLogFileURL: blockedDirectoryURL.appendingPathComponent("runtime.log")
        )

        let recoveredLogFileURL = temporaryRoot.appendingPathComponent("recovered.log")
        AppConsoleLogger.prepareRuntimeLogFileForLaunch(runtimeLogFileURL: recoveredLogFileURL)

        let output = unwrappedLogOutput(try String(contentsOf: recoveredLogFileURL, encoding: .utf8))
        XCTAssertTrue(output.contains("runtime_log_file_prepare_failed"))
        XCTAssertTrue(output.contains(#"stage="prepare_runtime_log_file""#))
        XCTAssertTrue(output.contains("runtime_log_pending_lines_flushed"))
        XCTAssertTrue(output.contains(#"recovery_stage="prepare_runtime_log_file""#))
    }

    func testMacRuntimeLogFileURLUsesUserLibraryLogsDirectory() throws {
        let url = try XCTUnwrap(AppConsoleLogger.runtimeLogFileURL())

        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, "YoutubeFeeder")
        XCTAssertEqual(url.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent, "Logs")
        XCTAssertEqual(url.lastPathComponent, "youtubefeeder-runtime.log")
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
            unwrappedLogOutput(rawOutput)
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
}
#endif
