import Foundation

enum AppConsoleLoggerRuntimeLogStore {
    private static let fileLogLock = NSLock()
    private static let runtimeLogLaunchLock = NSLock()
    private static var runtimeLogLaunchFileURL: URL?
    private static var pendingRuntimeLogLines: [String] = []

    static func prepareRuntimeLogFileForLaunch(runtimeLogFileURL overrideURL: URL? = nil) {
#if targetEnvironment(macCatalyst)
        let logFileURL = overrideURL ?? AppConsoleLoggerRuntimeLogLocator.runtimeLogLaunchFileURL()
        guard let logFileURL else {
            fileLogLock.lock()
            defer { fileLogLock.unlock() }
            appendPendingRuntimeLogDiagnostic(
                "runtime_log_file_prepare_failed",
                level: .warning,
                metadata: [
                    "reason": "launch_log_file_url_unavailable",
                    "pending_lines": "\(pendingRuntimeLogLines.count)",
                    "process_id": "\(ProcessInfo.processInfo.processIdentifier)",
                    "stage": "prepare_runtime_log_file"
                ]
            )
            return
        }

        do {
            let fileManager = FileManager.default
            runtimeLogLaunchLock.lock()
            runtimeLogLaunchFileURL = logFileURL
            runtimeLogLaunchLock.unlock()
            fileLogLock.lock()
            defer { fileLogLock.unlock() }

            try fileManager.createDirectory(
                at: logFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data().write(to: logFileURL, options: .atomic)
            let flushedCount = try flushPendingRuntimeLogLines(to: logFileURL)
            try writePendingRuntimeLogFlushDiagnosticIfNeeded(
                flushedCount: flushedCount,
                logFileURL: logFileURL,
                recoveryStage: "prepare_runtime_log_file"
            )
        } catch {
            fileLogLock.lock()
            defer { fileLogLock.unlock() }
            appendPendingRuntimeLogDiagnostic(
                "runtime_log_file_prepare_failed",
                level: .warning,
                metadata: runtimeLogFailureMetadata(
                    stage: "prepare_runtime_log_file",
                    logFileURL: logFileURL,
                    error: error
                )
            )
        }
#endif
    }

    static func writeFileLine(_ line: String) {
        appendRuntimeLogLine(line)
    }

    static func runtimeLogFileName() -> String? {
        AppConsoleLoggerRuntimeLogLocator.runtimeLogFileName()
    }

    static func runtimeLogOverrideStatus() -> String {
        AppConsoleLoggerRuntimeLogLocator.runtimeLogOverrideStatus()
    }

    static func runtimeLogOverrideFileName() -> String {
        AppConsoleLoggerRuntimeLogLocator.runtimeLogOverrideFileName()
    }

    static func launchRuntimeLogFileName(
        date: Date = .now,
        processIdentifier: Int32 = ProcessInfo.processInfo.processIdentifier
    ) -> String {
        AppConsoleLoggerRuntimeLogLocator.launchRuntimeLogFileName(date: date, processIdentifier: processIdentifier)
    }

    static func writeConsoleLine(_ line: String, level: AppConsoleLogLevel) {
        switch level {
        case .warning, .error:
            writeStandardErrorLine(line)
        case .debug, .info:
            print(line)
        }
    }

    private static func writeStandardErrorLine(_ line: String) {
        guard let data = (line + "\n").data(using: .utf8) else { return }
        FileHandle.standardError.write(data)
    }

    private static func appendRuntimeLogLine(_ line: String) {
#if targetEnvironment(macCatalyst)
        guard let logFileURL = activeRuntimeLogFileURL() else {
            fileLogLock.lock()
            defer { fileLogLock.unlock() }
            appendPendingRuntimeLogLine(line)
            appendPendingRuntimeLogDiagnostic(
                "runtime_log_file_write_deferred",
                level: .warning,
                metadata: [
                    "reason": "active_log_file_missing",
                    "pending_lines": "\(pendingRuntimeLogLines.count)",
                    "process_id": "\(ProcessInfo.processInfo.processIdentifier)"
                ]
            )
            return
        }
        fileLogLock.lock()
        defer { fileLogLock.unlock() }

        do {
            let fileManager = FileManager.default
            try fileManager.createDirectory(
                at: logFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = Data((line + "\n").utf8)
            let flushedCount = try flushPendingRuntimeLogLines(to: logFileURL)
            try writePendingRuntimeLogFlushDiagnosticIfNeeded(
                flushedCount: flushedCount,
                logFileURL: logFileURL,
                recoveryStage: "append_runtime_log_line"
            )
            if fileManager.fileExists(atPath: logFileURL.path) {
                let handle = try FileHandle(forWritingTo: logFileURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } else {
                try data.write(to: logFileURL, options: .atomic)
            }
        } catch {
            appendPendingRuntimeLogLine(line)
            appendPendingRuntimeLogDiagnostic(
                "runtime_log_file_write_deferred",
                level: .warning,
                metadata: runtimeLogFailureMetadata(
                    stage: "append_runtime_log_line",
                    logFileURL: logFileURL,
                    error: error
                )
            )
        }
#endif
    }

    private static func flushPendingRuntimeLogLines(to logFileURL: URL) throws -> Int {
        guard !pendingRuntimeLogLines.isEmpty else { return 0 }
        let lines = pendingRuntimeLogLines
        pendingRuntimeLogLines.removeAll()

        do {
            try writeRuntimeLogLines(lines, to: logFileURL)
            return lines.count
        } catch {
            pendingRuntimeLogLines = Array((lines + pendingRuntimeLogLines).suffix(AppConsoleLogger.maximumPendingRuntimeLogLines))
            throw error
        }
    }

    private static func appendPendingRuntimeLogLine(_ line: String) {
        pendingRuntimeLogLines.append(line)
        if pendingRuntimeLogLines.count > AppConsoleLogger.maximumPendingRuntimeLogLines {
            pendingRuntimeLogLines.removeFirst(pendingRuntimeLogLines.count - AppConsoleLogger.maximumPendingRuntimeLogLines)
        }
    }

    private static func appendPendingRuntimeLogDiagnostic(
        _ event: String,
        level: AppConsoleLogLevel,
        metadata: [String: String]
    ) {
        appendPendingRuntimeLogLine(runtimeLogDiagnosticLine(event, level: level, metadata: metadata))
    }

    private static func writePendingRuntimeLogFlushDiagnosticIfNeeded(
        flushedCount: Int,
        logFileURL: URL,
        recoveryStage: String
    ) throws {
        guard flushedCount > 0 else { return }
        try writeRuntimeLogLines(
            [
                runtimeLogDiagnosticLine(
                    "runtime_log_pending_lines_flushed",
                    level: .info,
                    metadata: [
                        "flushed_lines": "\(flushedCount)",
                        "log_file": logFileURL.lastPathComponent,
                        "process_id": "\(ProcessInfo.processInfo.processIdentifier)",
                        "recovery_stage": recoveryStage
                    ]
                )
            ],
            to: logFileURL
        )
    }

    private static func writeRuntimeLogLines(_ lines: [String], to logFileURL: URL) throws {
        guard !lines.isEmpty else { return }
        let data = Data((lines.joined(separator: "\n") + "\n").utf8)
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: logFileURL.path) {
            let handle = try FileHandle(forWritingTo: logFileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } else {
            try data.write(to: logFileURL, options: .atomic)
        }
    }

    private static func runtimeLogDiagnosticLine(
        _ event: String,
        level: AppConsoleLogLevel,
        metadata: [String: String]
    ) -> String {
        AppConsoleLogger.renderLine(
            .init(
                timestamp: AppConsoleLogger.timestamp(for: .now),
                level: level,
                scope: "app.lifecycle",
                event: event,
                message: nil,
                metadata: metadata
            )
        )
    }

    private static func runtimeLogFailureMetadata(stage: String, logFileURL: URL, error: Error) -> [String: String] {
        let fileManager = FileManager.default
        let directoryURL = logFileURL.deletingLastPathComponent()
        let directoryPath = directoryURL.path
        return [
            "directory_exists": "\(fileManager.fileExists(atPath: directoryPath))",
            "directory_writable": "\(fileManager.isWritableFile(atPath: directoryPath))",
            "error": AppConsoleLogger.errorSummary(error, limit: 160),
            "log_file": logFileURL.lastPathComponent,
            "pending_lines": "\(pendingRuntimeLogLines.count)",
            "process_id": "\(ProcessInfo.processInfo.processIdentifier)",
            "stage": stage
        ]
    }

    private static func runtimeLogFailureMetadata(stage: String, logFileURL: URL?, error: Error) -> [String: String] {
        guard let logFileURL else {
            return [
                "error": AppConsoleLogger.errorSummary(error, limit: 160),
                "log_file": "unknown",
                "pending_lines": "\(pendingRuntimeLogLines.count)",
                "process_id": "\(ProcessInfo.processInfo.processIdentifier)",
                "stage": stage
            ]
        }
        return runtimeLogFailureMetadata(stage: stage, logFileURL: logFileURL, error: error)
    }

    static func activeRuntimeLogFileURL() -> URL? {
#if targetEnvironment(macCatalyst)
        runtimeLogLaunchLock.lock()
        defer { runtimeLogLaunchLock.unlock() }

        if let override = AppConsoleLoggerRuntimeLogLocator.runtimeLogOverrideFileURL() {
            guard !isLegacyRuntimeLogFileURL(override) else {
                return runtimeLogLaunchFileURL
            }
            return override
        }

        return runtimeLogLaunchFileURL
#else
        return nil
#endif
    }

    static func runtimeLogFileURL(sourceFilePath: String = #filePath) -> URL? {
        AppConsoleLoggerRuntimeLogLocator.runtimeLogFileURL(sourceFilePath: sourceFilePath)
    }

    private static func isLegacyRuntimeLogFileURL(_ url: URL) -> Bool {
        url.lastPathComponent == AppConsoleLogger.legacyRuntimeLogFileName
    }
}
