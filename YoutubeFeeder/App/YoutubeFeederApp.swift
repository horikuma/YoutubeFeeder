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
                "launch_mode": {
                    switch AppLaunchMode.current {
                    case .normal:
                        return "normal"
                    case .uiTestMock:
                        return "ui_test_mock"
                    case .uiTestLive:
                        return "ui_test_live"
                    }
                }()
            ]
        )
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
