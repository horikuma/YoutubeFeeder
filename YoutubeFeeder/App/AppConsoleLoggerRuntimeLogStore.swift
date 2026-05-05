import Foundation

enum AppConsoleLoggerRuntimeLogStore {
    private static let buffer = AppConsoleLoggerRuntimeLogBuffer()

    static func prepareRuntimeLogFileForLaunch(runtimeLogFileURL overrideURL: URL? = nil) {
        buffer.prepareRuntimeLogFileForLaunch(runtimeLogFileURL: overrideURL)
    }

    static func writeFileLine(_ line: String) {
        buffer.writeFileLine(line)
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

    static func activeRuntimeLogFileURL() -> URL? {
        buffer.activeRuntimeLogFileURL()
    }

    static func runtimeLogFileURL(sourceFilePath: String = #filePath) -> URL? {
        AppConsoleLoggerRuntimeLogLocator.runtimeLogFileURL(sourceFilePath: sourceFilePath)
    }
}
