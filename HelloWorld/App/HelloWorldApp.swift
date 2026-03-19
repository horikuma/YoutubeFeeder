import SwiftUI

@main
struct HelloWorldApp: App {
    init() {
        UITestFixtureSeeder.seedIfNeeded()
        StartupDiagnostics.shared.mark("appLaunched")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
