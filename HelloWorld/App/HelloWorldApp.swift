//
//  HelloWorldApp.swift
//  HelloWorld
//
//  Created by 高下彰実 on 2026/03/11.
//

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
