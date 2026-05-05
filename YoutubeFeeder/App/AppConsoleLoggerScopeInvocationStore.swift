import Foundation

enum AppConsoleLoggerScopeInvocationStore {
    private struct ScopeInvocationWindow {
        var windowStartedAt: Date
        var count: Int
    }

    private static let lock = NSLock()
    private static var scopeInvocationWindows: [String: ScopeInvocationWindow] = [:]

    static func recordScopeInvocation(for scope: String, at timestamp: Date = .now) {
        lock.lock()
        defer { lock.unlock() }

        if let window = scopeInvocationWindows[scope],
            timestamp.timeIntervalSince(window.windowStartedAt) < AppConsoleLogger.scopeInvocationWindowSeconds {
            scopeInvocationWindows[scope] = ScopeInvocationWindow(
                windowStartedAt: window.windowStartedAt,
                count: window.count + 1
            )
            return
        }

        scopeInvocationWindows[scope] = ScopeInvocationWindow(windowStartedAt: timestamp, count: 1)
    }

    static func scopeInvocationCount(for scope: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return scopeInvocationWindows[scope]?.count ?? 0
    }

    static func removeScopeInvocationCount(for scope: String) -> Int? {
        lock.lock()
        defer { lock.unlock() }
        return scopeInvocationWindows.removeValue(forKey: scope)?.count
    }

    static func scopeInvocationThresholdExceeded(for scope: String, limit: Int) -> AppConsoleLogger.ScopeInvocationThresholdExceeded? {
        let count = scopeInvocationCount(for: scope)
        guard count > limit else { return nil }
        return .exceeded(scope: scope, count: count, limit: limit)
    }

    static func scopeInvocationThresholdExceeded(for scope: String) -> AppConsoleLogger.ScopeInvocationThresholdExceeded? {
        scopeInvocationThresholdExceeded(for: scope, limit: AppConsoleLogger.scopeInvocationThresholdCount)
    }

    static func scopeInvocationThresholdExceededWarning(for scope: String, limit: Int) -> AppConsoleLogger.ScopeInvocationThresholdExceeded? {
        guard let exceeded = scopeInvocationThresholdExceeded(for: scope, limit: limit) else { return nil }
        AppConsoleLogger.appLifecycle.warning(
            "scope_invocation_threshold_exceeded",
            metadata: [
                "kind": "threshold_exceeded",
                "scope": scope,
                "count": "\(scopeInvocationCount(for: scope))",
                "limit": "\(limit)"
            ]
        )
        return exceeded
    }

    static func scopeInvocationThresholdExceededWarning(for scope: String) -> AppConsoleLogger.ScopeInvocationThresholdExceeded? {
        guard let exceeded = scopeInvocationThresholdExceeded(for: scope) else { return nil }
        AppConsoleLogger.appLifecycle.warning(
            "scope_invocation_threshold_exceeded",
            metadata: [
                "kind": "threshold_exceeded",
                "scope": scope,
                "count": "\(scopeInvocationCount(for: scope))",
                "limit": "\(AppConsoleLogger.scopeInvocationThresholdCount)"
            ]
        )
        return exceeded
    }
}
