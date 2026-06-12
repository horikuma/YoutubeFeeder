import Foundation

enum AppConsoleLoggerRuntimeLogLocator {
    static func runtimeLogFileName() -> String? {
        activeRuntimeLogFileURL()?.lastPathComponent
    }

    static func runtimeLogOverrideStatus() -> String {
#if targetEnvironment(macCatalyst)
        guard let override = runtimeLogOverrideFileURL() else {
            return "none"
        }
        return isLegacyRuntimeLogFileURL(override) ? "ignored_legacy_runtime_log_file" : "active"
#else
        return "unsupported"
#endif
    }

    static func runtimeLogOverrideFileName() -> String {
#if targetEnvironment(macCatalyst)
        runtimeLogOverrideFileURL()?.lastPathComponent ?? "none"
#else
        "unsupported"
#endif
    }

    static func launchRuntimeLogFileName(
        date: Date = .now,
        processIdentifier: Int32 = ProcessInfo.processInfo.processIdentifier
    ) -> String {
        "youtubefeeder-runtime-\(AppConsoleLogger.runtimeLogLaunchFileNameFormatter.string(from: date))-pid\(processIdentifier).log"
    }

    static func runtimeLogFileURL() -> URL? {
#if targetEnvironment(macCatalyst)
        if let override = runtimeLogOverrideFileURL() {
            return override
        }

        guard let logDirectoryURL = defaultRuntimeLogDirectoryURL() else { return nil }
        return logDirectoryURL.appendingPathComponent(AppConsoleLogger.legacyRuntimeLogFileName)
#else
        return nil
#endif
    }

    static func runtimeLogLaunchFileURL() -> URL? {
#if targetEnvironment(macCatalyst)
        guard let logDirectoryURL = defaultRuntimeLogDirectoryURL() else { return nil }
        let fileName = launchRuntimeLogFileName(
            date: .now,
            processIdentifier: ProcessInfo.processInfo.processIdentifier
        )
        return logDirectoryURL.appendingPathComponent(fileName)
#else
        return nil
#endif
    }

    private static func activeRuntimeLogFileURL() -> URL? {
#if targetEnvironment(macCatalyst)
        AppConsoleLoggerRuntimeLogStore.activeRuntimeLogFileURL()
#else
        return nil
#endif
    }

    private static func defaultRuntimeLogDirectoryURL() -> URL? {
#if targetEnvironment(macCatalyst)
        guard let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            return nil
        }
        return libraryURL
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent(AppConsoleLogger.runtimeLogDirectoryName, isDirectory: true)
#else
        return nil
#endif
    }

    static func runtimeLogOverrideFileURL() -> URL? {
#if targetEnvironment(macCatalyst)
        guard let override = ProcessInfo.processInfo.environment["YOUTUBEFEEDER_RUNTIME_LOG_FILE"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !override.isEmpty
        else {
            return nil
        }
        return URL(fileURLWithPath: override)
#else
        return nil
#endif
    }

    private static func isLegacyRuntimeLogFileURL(_ url: URL) -> Bool {
        url.lastPathComponent == AppConsoleLogger.legacyRuntimeLogFileName
    }
}
