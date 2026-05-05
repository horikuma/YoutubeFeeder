import Foundation

enum AppConsoleLoggerTraceStore {
    private static let lock = NSLock()
    private static var traceStartTimes: [String: Date] = [:]

    static func traceID() -> String {
        UUID().uuidString
    }

    static func recordTraceStart(_ traceID: String, startedAt: Date = .now) {
        lock.lock()
        defer { lock.unlock() }
        traceStartTimes[traceID] = startedAt
    }

    static func traceStartTime(for traceID: String) -> Date? {
        lock.lock()
        defer { lock.unlock() }
        return traceStartTimes[traceID]
    }

    static func removeTraceStartTime(for traceID: String) -> Date? {
        lock.lock()
        defer { lock.unlock() }
        return traceStartTimes.removeValue(forKey: traceID)
    }

    static func traceEndMismatch(for traceID: String, startedAt: Date?) -> AppConsoleLogger.TraceLifecycleMismatch? {
        guard startedAt == nil else { return nil }
        return .missingStart(traceID: traceID)
    }

    static func traceStartMismatch() -> AppConsoleLogger.TraceLifecycleMismatch? {
        lock.lock()
        defer { lock.unlock() }
        let traceIDs = traceStartTimes.keys.sorted()
        guard !traceIDs.isEmpty else { return nil }
        return .unfinishedStarts(traceIDs: traceIDs)
    }

    static func traceEndMismatchWarning(for traceID: String, startedAt: Date?) -> AppConsoleLogger.TraceLifecycleMismatch? {
        guard let mismatch = traceEndMismatch(for: traceID, startedAt: startedAt) else { return nil }
        AppConsoleLogger.appLifecycle.warning(
            "trace_lifecycle_mismatch",
            metadata: [
                "kind": "missing_start",
                "trace_id": traceID
            ]
        )
        return mismatch
    }

    static func traceStartMismatchWarning() -> AppConsoleLogger.TraceLifecycleMismatch? {
        guard case let .unfinishedStarts(traceIDs)? = traceStartMismatch() else { return nil }
        AppConsoleLogger.appLifecycle.warning(
            "trace_lifecycle_mismatch",
            metadata: [
                "count": String(traceIDs.count),
                "kind": "unfinished_starts",
                "trace_ids": traceIDs.joined(separator: ",")
            ]
        )
        return .unfinishedStarts(traceIDs: traceIDs)
    }
}
