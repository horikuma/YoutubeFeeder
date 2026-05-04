import Foundation
import SwiftUI
import Combine

enum AppLaunchMode {
    case normal
    case uiTestMock
    case uiTestLive

    static var current: AppLaunchMode {
        guard ProcessInfo.processInfo.environment["YOUTUBEFEEDER_UI_TEST_MODE"] == "1" else {
            return .normal
        }
        let usesMockData = ProcessInfo.processInfo.environment["YOUTUBEFEEDER_UI_TEST_USE_MOCK"] != "0"
        return usesMockData ? .uiTestMock : .uiTestLive
    }

    var usesMockData: Bool {
        self == .uiTestMock
    }

    var isUITest: Bool {
        self != .normal
    }

    var allowsBackgroundRefresh: Bool {
        self == .normal
    }

    var autoRefreshOnLaunch: Bool {
        Self.autoRefreshOnLaunch(
            mode: self,
            uiTestAutoRefreshEnabled: ProcessInfo.processInfo.environment["YOUTUBEFEEDER_UI_TEST_AUTO_REFRESH"] == "1"
        )
    }

    static func autoRefreshOnLaunch(mode: AppLaunchMode, uiTestAutoRefreshEnabled: Bool) -> Bool {
        switch mode {
        case .normal:
            return true
        case .uiTestMock, .uiTestLive:
            return uiTestAutoRefreshEnabled
        }
    }

    var initialUITestRoute: UITestInitialRoute? {
        guard isUITest else { return nil }
        return UITestInitialRoute(rawValue: ProcessInfo.processInfo.environment["YOUTUBEFEEDER_UI_TEST_INITIAL_ROUTE"] ?? "")
    }

    var runtimeLoggingEnabled: Bool {
        ProcessInfo.processInfo.environment["YOUTUBEFEEDER_RUNTIME_LOGGING"] == "1"
    }
}

enum UITestInitialRoute: String {
    case allVideos
    case channelSearchResults
    case channelRegistration
    case channelList
}

enum UITestRemoteSearchFixtureVariant: String {
    case baseline
    case heavy

    static var current: UITestRemoteSearchFixtureVariant {
        UITestRemoteSearchFixtureVariant(
            rawValue: ProcessInfo.processInfo.environment["YOUTUBEFEEDER_UI_TEST_REMOTE_SEARCH_FIXTURE"] ?? ""
        ) ?? .baseline
    }
}

@MainActor
final class StartupDiagnostics: ObservableObject {
    static let shared = StartupDiagnostics()

    @Published private(set) var timelineValue = "{}"

    private let processStartedAt = Date(timeIntervalSinceNow: -ProcessInfo.processInfo.systemUptime)
    private var events: [String: Date] = [:]
    private var didEmitStartupProfile = false
    private let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    func mark(_ event: String, at date: Date = .now) {
        events[event] = date
        timelineValue = encodedTimeline()
        emitStartupProfileIfReady()
    }

    var startupProfileT0: Date {
        processStartedAt
    }

    var startupProfileT1: Date? {
        events["appLaunched"]
    }

    var startupProfileT2: Date? {
        firstInitialDisplayAt()
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

    private func emitStartupProfileIfReady() {
        guard !didEmitStartupProfile else { return }
        guard let appLaunchedAt = events["appLaunched"] else { return }
        guard let initialDisplayAt = firstInitialDisplayAt() else { return }

        didEmitStartupProfile = true
        AppConsoleLogger.appLifecycle.info(
            "startup_profile",
            metadata: [
                "T0": formatter.string(from: processStartedAt),
                "T1": formatter.string(from: appLaunchedAt),
                "T2": formatter.string(from: initialDisplayAt),
                "T0_T1_ms": String(Int(appLaunchedAt.timeIntervalSince(processStartedAt) * 1000)),
                "T1_T2_ms": String(Int(initialDisplayAt.timeIntervalSince(appLaunchedAt) * 1000))
            ]
        )
    }

    private func firstInitialDisplayAt() -> Date? {
        [
            events["splashShown"],
            events["bootstrapLoaded"],
            events["maintenanceEntered"],
            events["channelListShown"],
            events["channelVideosShown"],
            events["keywordSearchShown"],
            events["allVideosShown"]
        ]
        .compactMap { $0 }
        .min()
    }
}

struct RuntimeLogEntry: Codable, Hashable {
    let timestamp: String
    let event: String
    let detail: String
    let metadata: [String: String]
}

@MainActor
final class RuntimeDiagnostics: ObservableObject {
    static let shared = RuntimeDiagnostics()

    @Published private(set) var latestValue = "[]"

    private let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private var entries: [RuntimeLogEntry] = []

    var isEnabled: Bool {
        AppLaunchMode.current.runtimeLoggingEnabled
    }

    func record(_ event: String, detail: String, metadata: [String: String] = [:]) {
        guard isEnabled else { return }

        let entry = RuntimeLogEntry(
            timestamp: formatter.string(from: .now),
            event: event,
            detail: detail,
            metadata: metadata.sorted { $0.key < $1.key }.reduce(into: [String: String]()) { partial, pair in
                partial[pair.key] = pair.value
            }
        )

        entries.append(entry)
        if entries.count > 200 {
            entries.removeFirst(entries.count - 200)
        }
        latestValue = encodedEntries()

        if
            let data = try? JSONEncoder().encode(entry),
            let line = String(data: data, encoding: .utf8) {
            print("YOUTUBEFEEDER_RUNTIME_LOG \(line)")
        } else {
            print("YOUTUBEFEEDER_RUNTIME_LOG {\"event\":\"\(event)\",\"detail\":\"\(detail)\"}")
        }
    }

    private func encodedEntries() -> String {
        guard
            let data = try? JSONEncoder().encode(entries),
            let string = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }

        return string
    }
}
