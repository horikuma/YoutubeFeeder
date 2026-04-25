import SwiftUI

@main
struct YoutubeFeederApp: App {
    @ObservedObject private var refreshCommandCenter = RefreshCommandCenter.shared

    init() {
        UITestFixtureSeeder.seedIfNeeded()
        AppConsoleLogger.prepareRuntimeLogFileForLaunch()
        StartupDiagnostics.shared.mark("appLaunched")
        AppConsoleLogger.appLifecycle.info(
            "app_launch",
            metadata: [
                "app_version": Self.bundleValue(forInfoDictionaryKey: "CFBundleShortVersionString"),
                "launch_mode": {
                    switch AppLaunchMode.current {
                    case .normal:
                        return "normal"
                    case .uiTestMock:
                        return "ui_test_mock"
                    case .uiTestLive:
                        return "ui_test_live"
                    }
                }(),
                "build_version": Self.bundleValue(forInfoDictionaryKey: "CFBundleVersion"),
                "runtime_log_file": AppConsoleLogger.runtimeLogFileName() ?? "unknown"
            ]
        )
    }

    private static func bundleValue(forInfoDictionaryKey key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "unknown"
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
#if targetEnvironment(macCatalyst)
        .commands {
            CommandMenu("Refresh") {
                Button("Refresh") {
                    Task {
                        await refreshCommandCenter.performCurrentRefresh()
                    }
                }
                .disabled(!refreshCommandCenter.isAvailable)
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
#endif
    }
}
