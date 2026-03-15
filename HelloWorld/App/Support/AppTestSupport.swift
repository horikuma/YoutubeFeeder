import Foundation
import SwiftUI
import Combine

enum AppLaunchMode {
    case normal
    case uiTestMock

    static var current: AppLaunchMode {
        ProcessInfo.processInfo.environment["HELLOWORLD_UI_TEST_MODE"] == "1" ? .uiTestMock : .normal
    }

    var usesMockData: Bool {
        self == .uiTestMock
    }

    var allowsBackgroundRefresh: Bool {
        self == .normal
    }

    var autoRefreshOnLaunch: Bool {
        ProcessInfo.processInfo.environment["HELLOWORLD_UI_TEST_AUTO_REFRESH"] == "1"
    }

    var initialUITestRoute: UITestInitialRoute? {
        guard usesMockData else { return nil }
        return UITestInitialRoute(rawValue: ProcessInfo.processInfo.environment["HELLOWORLD_UI_TEST_INITIAL_ROUTE"] ?? "")
    }
}

enum UITestInitialRoute: String {
    case allVideos
    case channelRegistration
    case channelList
}

@MainActor
final class StartupDiagnostics: ObservableObject {
    static let shared = StartupDiagnostics()

    @Published private(set) var timelineValue = "{}"

    private var events: [String: Date] = [:]
    private let formatter = ISO8601DateFormatter()

    func mark(_ event: String, at date: Date = .now) {
        events[event] = date
        timelineValue = encodedTimeline()
    }

    private func encodedTimeline() -> String {
        let origin = events["appLaunched"]
        let payload = events.keys.sorted().reduce(into: [String: [String: String]]()) { partial, key in
            guard let date = events[key] else { return }
            var item = ["timestamp": formatter.string(from: date)]
            if let origin {
                item["offset_ms"] = String(Int(date.timeIntervalSince(origin) * 1000))
            }
            partial[key] = item
        }

        guard
            let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
            let string = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }

        return string
    }
}

enum UITestFixtureSeeder {
    static func seedIfNeeded(bundle: Bundle = .main, fileManager: FileManager = .default) {
        guard AppLaunchMode.current.usesMockData else { return }

        let baseDirectory = FeedCachePaths.baseDirectory(fileManager: fileManager)
        try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)

        try? fileManager.removeItem(at: FeedCachePaths.channelRegistryURL(fileManager: fileManager))
        copyFixture(named: "UITest.bootstrap", extension: "json", to: FeedCachePaths.bootstrapURL(fileManager: fileManager), bundle: bundle)
        copyFixture(named: "UITest.cache", extension: "json", to: FeedCachePaths.cacheURL(fileManager: fileManager), bundle: bundle)
    }

    private static func copyFixture(named name: String, extension ext: String, to destination: URL, bundle: Bundle) {
        guard let source = bundle.url(forResource: name, withExtension: ext) else { return }
        try? FileManager.default.removeItem(at: destination)
        try? FileManager.default.copyItem(at: source, to: destination)
    }
}

private struct DiagnosticsProbe: View {
    @ObservedObject var diagnostics = StartupDiagnostics.shared

    var body: some View {
        if AppLaunchMode.current.usesMockData {
            Text("diagnostics")
                .font(.caption2)
                .foregroundStyle(.clear)
                .accessibilityIdentifier("diagnostics.timeline")
                .accessibilityValue(diagnostics.timelineValue)
        }
    }
}

extension View {
    func attachDiagnosticsProbe() -> some View {
        overlay(alignment: .topLeading) {
            DiagnosticsProbe()
                .frame(width: 1, height: 1)
        }
    }
}

struct UITestMarker: View {
    let identifier: String
    let value: String

    var body: some View {
        Text(value)
            .font(.caption2)
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .accessibilityIdentifier(identifier)
            .accessibilityLabel(value)
    }
}
