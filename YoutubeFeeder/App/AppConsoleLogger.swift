import Foundation

enum AppConsoleLogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"

    static let notice = AppConsoleLogLevel.info

    var priority: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        }
    }
}

struct AppConsoleLogger {
    enum TraceLifecycleMismatch: Equatable {
        case missingStart(traceID: String)
        case unfinishedStarts(traceIDs: [String])
    }

    enum ScopeInvocationThresholdExceeded: Equatable {
        case exceeded(scope: String, count: Int, limit: Int)
    }

    struct RenderLineParams {
        let timestamp: String
        let level: AppConsoleLogLevel
        let scope: String
        let event: String
        let message: String?
        let metadata: [String: String]
    }

    static let appLifecycle = AppConsoleLogger(scope: "app.lifecycle")
    static let channelRegistry = AppConsoleLogger(scope: "channel.registry")
    static let channelRegistryTransfer = AppConsoleLogger(scope: "channel_registry.transfer")
    static let cloudflareSync = AppConsoleLogger(scope: "cloudflare.sync")
    static let homeTransfer = AppConsoleLogger(scope: "home.transfer")
    static let feedRefresh = AppConsoleLogger(scope: "feed.refresh")
    static let youtubeSearch = AppConsoleLogger(scope: "youtube.search")
    static let remoteSearchSplitLoad = AppConsoleLogger(scope: "remote_search.split_load")
    static let browseTileInteraction = AppConsoleLogger(scope: "browse.tile.interaction")

    static let prefix = "[YoutubeFeeder]"
    static let projectRootMarker = "YoutubeFeeder/App/AppConsoleLogger.swift"
    static let runtimeLogDirectoryRelativePath = "logs"
    static let legacyRuntimeLogFileName = "youtubefeeder-runtime.log"
    static let maximumPendingRuntimeLogLines = 200
    static let minimumLogLevel: AppConsoleLogLevel = .info
    static let scopeInvocationWindowSeconds: TimeInterval = 1
    static let scopeInvocationThresholdCount: Int = 50
    static let runtimeLogLaunchFileNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return formatter
    }()

    let scope: String

    static func timestamp(for date: Date = .now) -> String {
        AppConsoleLoggerFormatting.timestamp(for: date)
    }

    func debug(_ event: String, message: String? = nil, metadata: [String: String] = [:]) { emit(level: .debug, event: event, message: message, metadata: metadata) }
    func info(_ event: String, message: String? = nil, metadata: [String: String] = [:]) { emit(level: .info, event: event, message: message, metadata: metadata) }
    func warning(_ event: String, message: String? = nil, metadata: [String: String] = [:]) { emit(level: .warning, event: event, message: message, metadata: metadata) }
    func notice(_ event: String, message: String? = nil, metadata: [String: String] = [:]) { emit(level: .info, event: event, message: message, metadata: metadata) }
    func error(_ event: String, message: String? = nil, metadata: [String: String] = [:]) { emit(level: .error, event: event, message: message, metadata: metadata) }

    private func emit(level: AppConsoleLogLevel, event: String, message: String?, metadata: [String: String]) {
        guard level.priority >= Self.minimumLogLevel.priority else { return }
        AppConsoleLoggerScopeInvocationStore.recordScopeInvocation(for: scope)
        let line = Self.renderLine(.init(
            timestamp: Self.timestamp(for: .now),
            level: level,
            scope: scope,
            event: event,
            message: message,
            metadata: metadata
        ))
        Self.writeConsoleLine(line, level: level)
        AppConsoleLoggerRuntimeLogStore.writeFileLine(line)
    }

    static func writeConsoleLine(_ line: String, level: AppConsoleLogLevel) {
        AppConsoleLoggerRuntimeLogStore.writeConsoleLine(line, level: level)
    }

    static func writeFileLine(_ line: String) {
        AppConsoleLoggerRuntimeLogStore.writeFileLine(line)
    }

    static func prepareRuntimeLogFileForLaunch(runtimeLogFileURL overrideURL: URL? = nil) {
        AppConsoleLoggerRuntimeLogStore.prepareRuntimeLogFileForLaunch(runtimeLogFileURL: overrideURL)
    }

    static func recordScopeInvocation(for scope: String, at timestamp: Date = .now) {
        AppConsoleLoggerScopeInvocationStore.recordScopeInvocation(for: scope, at: timestamp)
    }

    static func scopeInvocationCount(for scope: String) -> Int {
        AppConsoleLoggerScopeInvocationStore.scopeInvocationCount(for: scope)
    }

    static func removeScopeInvocationCount(for scope: String) -> Int? {
        AppConsoleLoggerScopeInvocationStore.removeScopeInvocationCount(for: scope)
    }

    static func scopeInvocationThresholdExceeded(for scope: String, limit: Int) -> ScopeInvocationThresholdExceeded? {
        AppConsoleLoggerScopeInvocationStore.scopeInvocationThresholdExceeded(for: scope, limit: limit)
    }

    static func scopeInvocationThresholdExceeded(for scope: String) -> ScopeInvocationThresholdExceeded? {
        AppConsoleLoggerScopeInvocationStore.scopeInvocationThresholdExceeded(for: scope)
    }

    static func scopeInvocationThresholdExceededWarning(for scope: String, limit: Int) -> ScopeInvocationThresholdExceeded? {
        AppConsoleLoggerScopeInvocationStore.scopeInvocationThresholdExceededWarning(for: scope, limit: limit)
    }

    static func scopeInvocationThresholdExceededWarning(for scope: String) -> ScopeInvocationThresholdExceeded? {
        AppConsoleLoggerScopeInvocationStore.scopeInvocationThresholdExceededWarning(for: scope)
    }

    static func renderLine(_ params: RenderLineParams) -> String {
        AppConsoleLoggerFormatting.renderLine(params)
    }

    static func sanitizedKeyword(_ keyword: String, limit: Int = 48) -> String {
        AppConsoleLoggerFormatting.sanitizedKeyword(keyword, limit: limit)
    }

    static func responsePreview(_ data: Data, limit: Int = 160) -> String {
        AppConsoleLoggerFormatting.responsePreview(data, limit: limit)
    }

    static func errorSummary(_ error: Error, limit: Int = 120) -> String {
        AppConsoleLoggerFormatting.errorSummary(error, limit: limit)
    }

    static func elapsedMilliseconds(since startedAt: Date) -> String {
        AppConsoleLoggerFormatting.elapsedMilliseconds(since: startedAt)
    }

    static func elapsedMilliseconds(from startedAt: Date, to endedAt: Date) -> String {
        AppConsoleLoggerFormatting.elapsedMilliseconds(from: startedAt, to: endedAt)
    }

    static func traceDurationMilliseconds(since startedAt: Date, to endedAt: Date = .now) -> String {
        AppConsoleLoggerFormatting.traceDurationMilliseconds(since: startedAt, to: endedAt)
    }

    static func traceID() -> String {
        AppConsoleLoggerTraceStore.traceID()
    }

    static func recordTraceStart(_ traceID: String, startedAt: Date = .now) {
        AppConsoleLoggerTraceStore.recordTraceStart(traceID, startedAt: startedAt)
    }

    static func traceStartTime(for traceID: String) -> Date? {
        AppConsoleLoggerTraceStore.traceStartTime(for: traceID)
    }

    static func removeTraceStartTime(for traceID: String) -> Date? {
        AppConsoleLoggerTraceStore.removeTraceStartTime(for: traceID)
    }

    static func traceEndMismatch(for traceID: String, startedAt: Date?) -> TraceLifecycleMismatch? {
        AppConsoleLoggerTraceStore.traceEndMismatch(for: traceID, startedAt: startedAt)
    }

    static func traceStartMismatch() -> TraceLifecycleMismatch? {
        AppConsoleLoggerTraceStore.traceStartMismatch()
    }

    static func traceEndMismatchWarning(for traceID: String, startedAt: Date?) -> TraceLifecycleMismatch? {
        AppConsoleLoggerTraceStore.traceEndMismatchWarning(for: traceID, startedAt: startedAt)
    }

    static func traceStartMismatchWarning() -> TraceLifecycleMismatch? {
        AppConsoleLoggerTraceStore.traceStartMismatchWarning()
    }

    func traceStart(_ event: String, message: String? = nil, metadata: [String: String] = [:]) -> String {
        let traceID = Self.traceID()
        Self.recordTraceStart(traceID)
        emit(level: .info, event: event, message: message, metadata: metadata)
        return traceID
    }

    func traceEnd(_ event: String, traceID: String, message: String? = nil, count: String? = nil, size: String? = nil, result: String? = nil, metadata: [String: String] = [:]) -> Date? {
        let startedAt = Self.removeTraceStartTime(for: traceID)
        var traceMetadata = metadata
        traceMetadata["trace_id"] = traceID
        if let count { traceMetadata["count"] = count }
        if let size { traceMetadata["size"] = size }
        if let result { traceMetadata["result"] = result }
        if let startedAt { traceMetadata["duration_ms"] = Self.traceDurationMilliseconds(since: startedAt) }
        emit(level: .info, event: event, message: message, metadata: traceMetadata)
        return startedAt
    }

    func traceEvent(_ event: String, traceID: String, message: String? = nil, metadata: [String: String] = [:]) {
        guard Self.isAllowedEventLog(event) else { return }
        var traceMetadata = metadata
        traceMetadata["trace_id"] = traceID
        emit(level: .info, event: event, message: message, metadata: traceMetadata)
    }

    static func mainThreadFlag() -> String {
        AppConsoleLoggerFormatting.mainThreadFlag()
    }

    static func channelIDsFingerprint(_ channelIDs: [String]) -> String {
        AppConsoleLoggerFormatting.channelIDsFingerprint(channelIDs)
    }

    static func runtimeLogFileName() -> String? {
        AppConsoleLoggerRuntimeLogStore.runtimeLogFileName()
    }

    static func runtimeLogOverrideStatus() -> String {
        AppConsoleLoggerRuntimeLogStore.runtimeLogOverrideStatus()
    }

    static func runtimeLogOverrideFileName() -> String {
        AppConsoleLoggerRuntimeLogStore.runtimeLogOverrideFileName()
    }

    static func launchRuntimeLogFileName(date: Date = .now, processIdentifier: Int32 = ProcessInfo.processInfo.processIdentifier) -> String {
        AppConsoleLoggerRuntimeLogStore.launchRuntimeLogFileName(date: date, processIdentifier: processIdentifier)
    }

    static func runtimeLogFileURL(sourceFilePath: String = #filePath) -> URL? {
        AppConsoleLoggerRuntimeLogStore.runtimeLogFileURL(sourceFilePath: sourceFilePath)
    }

    private static func isAllowedEventLog(_ event: String) -> Bool {
        event.hasPrefix("state_change_") || event.hasPrefix("anomaly_") || event.hasPrefix("important_")
    }
}
