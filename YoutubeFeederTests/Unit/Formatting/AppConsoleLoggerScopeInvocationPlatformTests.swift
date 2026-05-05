import Foundation
import XCTest
@testable import YoutubeFeeder

#if targetEnvironment(macCatalyst)
final class AppConsoleLoggerScopeInvocationPlatformTests: LoggedTestCase {
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
}
#endif

