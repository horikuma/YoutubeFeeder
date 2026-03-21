import SwiftUI

@main
struct YoutubeFeederApp: App {
    init() {
        UITestFixtureSeeder.seedIfNeeded()
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
    }
}
