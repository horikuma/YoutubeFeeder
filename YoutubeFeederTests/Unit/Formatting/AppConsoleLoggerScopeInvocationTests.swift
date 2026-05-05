import Foundation
import XCTest
@testable import YoutubeFeeder

final class AppConsoleLoggerScopeInvocationTests: LoggedTestCase {
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
}

