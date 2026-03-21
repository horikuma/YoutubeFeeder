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
        ProcessInfo.processInfo.environment["YOUTUBEFEEDER_UI_TEST_AUTO_REFRESH"] == "1"
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

    private var events: [String: Date] = [:]
    private let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

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
            let line = String(data: data, encoding: .utf8)
        {
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

enum UITestFixtureSeeder {
    private static let remoteSearchKeyword = "ゆっくり実況"

    static func seedIfNeeded(bundle: Bundle = .main, fileManager: FileManager = .default) {
        guard AppLaunchMode.current.usesMockData else { return }

        let baseDirectory = FeedCachePaths.baseDirectory(fileManager: fileManager)
        try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        FeedCacheSQLiteDatabase.resetShared(fileManager: fileManager)
        removeDatabaseFiles(baseDirectory: baseDirectory, fileManager: fileManager)
        clearRemoteSearchFixtures(baseDirectory: baseDirectory, fileManager: fileManager)
        copyFixture(named: "UITest.bootstrap", extension: "json", to: FeedCachePaths.bootstrapURL(fileManager: fileManager), bundle: bundle)
        seedChannelRegistryFixture(bundle: bundle, fileManager: fileManager)
        seedCacheFixture(bundle: bundle, fileManager: fileManager)
        applyRemoteSearchFixtureVariantIfNeeded(baseDirectory: baseDirectory, fileManager: fileManager)
    }

    private static let legacyCacheDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static let bootstrapEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static func copyFixture(named name: String, extension ext: String, to destination: URL, bundle: Bundle) {
        guard let source = bundle.url(forResource: name, withExtension: ext) else { return }
        try? FileManager.default.removeItem(at: destination)
        try? FileManager.default.copyItem(at: source, to: destination)
    }

    private static func seedChannelRegistryFixture(bundle: Bundle, fileManager: FileManager) {
        guard let source = bundle.url(forResource: "UITest.channel-registry", withExtension: "json") else { return }
        guard
            let data = try? Data(contentsOf: source),
            let snapshot = try? JSONDecoder().decode(ChannelRegistrySnapshot.self, from: data)
        else {
            return
        }
        try? ChannelRegistryStore.replaceChannels(snapshot.channels, fileManager: fileManager)
    }

    private static func seedCacheFixture(bundle: Bundle, fileManager: FileManager) {
        guard let source = bundle.url(forResource: "UITest.cache", withExtension: "json") else { return }
        guard
            let data = try? Data(contentsOf: source),
            let snapshot = try? legacyCacheDecoder.decode(FeedCacheSnapshot.self, from: data)
        else {
            return
        }

        FeedCacheSQLiteDatabase.shared(fileManager: fileManager).replaceFeedSnapshot(snapshot)
    }

    private static func clearRemoteSearchFixtures(baseDirectory: URL, fileManager: FileManager) {
        let filenames = (try? fileManager.contentsOfDirectory(atPath: baseDirectory.path)) ?? []
        let targets = filenames.filter {
            ($0 == "remote-search.json" || $0.hasPrefix("remote-search-")) && $0.hasSuffix(".json")
        }
        for filename in targets {
            try? fileManager.removeItem(at: baseDirectory.appendingPathComponent(filename))
        }
        _ = FeedCacheSQLiteDatabase.shared(fileManager: fileManager).clearAllRemoteSearch()
    }

    private static func removeDatabaseFiles(baseDirectory: URL, fileManager: FileManager) {
        let filenames = [
            "feed-cache.sqlite",
            "feed-cache.sqlite-shm",
            "feed-cache.sqlite-wal",
        ]
        for filename in filenames {
            try? fileManager.removeItem(at: baseDirectory.appendingPathComponent(filename))
        }
    }

    private static func applyRemoteSearchFixtureVariantIfNeeded(baseDirectory: URL, fileManager: FileManager) {
        switch UITestRemoteSearchFixtureVariant.current {
        case .baseline:
            break
        case .heavy:
            seedHeavyRemoteSearchFixture(baseDirectory: baseDirectory, fileManager: fileManager)
        }
    }

    private static func seedHeavyRemoteSearchFixture(baseDirectory: URL, fileManager: FileManager) {
        let bootstrapURL = FeedCachePaths.bootstrapURL(fileManager: fileManager)
        let database = FeedCacheSQLiteDatabase.shared(fileManager: fileManager)
        var cacheSnapshot = database.loadFeedSnapshot()

        let alphaChannelID = "UC_TEST_ALPHA"
        let alphaTitle = "Alpha Channel"
        let savedAt = cacheSnapshot.savedAt == .distantPast ? Date(timeIntervalSince1970: 1_773_399_605) : cacheSnapshot.savedAt
        let heavyAlphaVideos = makeHeavyAlphaVideos(savedAt: savedAt, channelID: alphaChannelID, channelTitle: alphaTitle)
        let remoteVideos = Array(heavyAlphaVideos.prefix(100))
        cacheSnapshot = mergeHeavyAlphaFixture(
            into: cacheSnapshot,
            channelID: alphaChannelID,
            channelTitle: alphaTitle,
            savedAt: savedAt,
            heavyAlphaVideos: heavyAlphaVideos
        )

        database.replaceFeedSnapshot(cacheSnapshot)
        updateBootstrapFixture(
            bootstrapURL: bootstrapURL,
            channelID: alphaChannelID,
            channelTitle: alphaTitle,
            savedAt: savedAt,
            heavyAlphaVideos: heavyAlphaVideos,
            cachedVideoCount: cacheSnapshot.videos.count
        )
        writeHeavyRemoteSearchFixture(
            remoteVideos: remoteVideos,
            savedAt: savedAt,
            fileManager: fileManager
        )
    }

    private static func mergeHeavyAlphaFixture(
        into snapshot: FeedCacheSnapshot,
        channelID: String,
        channelTitle: String,
        savedAt: Date,
        heavyAlphaVideos: [CachedVideo]
    ) -> FeedCacheSnapshot {
        var updatedSnapshot = snapshot
        var mergedVideos = Dictionary(uniqueKeysWithValues: updatedSnapshot.videos.map { ($0.id, $0) })
        for video in heavyAlphaVideos {
            mergedVideos[video.id] = video
        }
        updatedSnapshot.videos = mergedVideos.values.sorted(by: sortCachedVideosDescending)
        updatedSnapshot.savedAt = savedAt
        updatedSnapshot.channels = updatedSnapshot.channels.map { channel in
            guard channel.channelID == channelID else { return channel }
            var updated = channel
            updated.cachedVideoCount = heavyAlphaVideos.count
            updated.channelTitle = channelTitle
            updated.lastAttemptAt = savedAt
            updated.lastCheckedAt = savedAt
            updated.lastSuccessAt = savedAt
            updated.latestPublishedAt = heavyAlphaVideos.first?.publishedAt
            updated.lastError = nil
            return updated
        }
        return updatedSnapshot
    }

    private static func updateBootstrapFixture(
        bootstrapURL: URL,
        channelID: String,
        channelTitle: String,
        savedAt: Date,
        heavyAlphaVideos: [CachedVideo],
        cachedVideoCount: Int
    ) {
        guard
            let bootstrapData = try? Data(contentsOf: bootstrapURL),
            var bootstrapSnapshot = try? legacyCacheDecoder.decode(FeedBootstrapSnapshot.self, from: bootstrapData)
        else {
            return
        }

        bootstrapSnapshot.progress = CacheProgress(
            totalChannels: bootstrapSnapshot.progress.totalChannels,
            cachedChannels: max(bootstrapSnapshot.progress.cachedChannels, 1),
            cachedVideos: cachedVideoCount,
            cachedThumbnails: bootstrapSnapshot.progress.cachedThumbnails,
            currentChannelID: bootstrapSnapshot.progress.currentChannelID,
            currentChannelNumber: bootstrapSnapshot.progress.currentChannelNumber,
            lastUpdatedAt: savedAt,
            isRunning: false,
            lastError: nil
        )
        bootstrapSnapshot.maintenanceItems = bootstrapSnapshot.maintenanceItems.map { item in
            guard item.channelID == channelID else { return item }
            return ChannelMaintenanceItem(
                id: item.id,
                channelID: item.channelID,
                channelTitle: channelTitle,
                lastSuccessAt: savedAt,
                lastCheckedAt: savedAt,
                latestPublishedAt: heavyAlphaVideos.first?.publishedAt,
                cachedVideoCount: heavyAlphaVideos.count,
                lastError: nil,
                freshness: .fresh
            )
        }
        if let encodedBootstrap = try? bootstrapEncoder.encode(bootstrapSnapshot) {
            try? encodedBootstrap.write(to: bootstrapURL, options: [.atomic])
        }
    }

    private static func writeHeavyRemoteSearchFixture(
        remoteVideos: [CachedVideo],
        savedAt: Date,
        fileManager: FileManager
    ) {
        let remoteEntry = RemoteVideoSearchCacheEntry(
            keyword: remoteSearchKeyword,
            videos: remoteVideos,
            totalCount: remoteVideos.count,
            fetchedAt: savedAt
        )
        FeedCacheSQLiteDatabase.shared(fileManager: fileManager).saveRemoteSearchEntry(remoteEntry)
    }

    private static func makeHeavyAlphaVideos(savedAt: Date, channelID: String, channelTitle: String) -> [CachedVideo] {
        let calendar = Calendar(identifier: .gregorian)
        return (0..<220).compactMap { index in
            let publishedAt = calendar.date(byAdding: .minute, value: -(index * 5), to: savedAt)
            let rank = 220 - index
            let identifier = String(format: "alpha-heavy-%03d", rank)
            let title = index < 100
                ? "ゆっくり実況 Alpha Heavy \(rank)"
                : "Alpha Archive \(rank)"
            let searchableText = [
                title.lowercased(),
                channelTitle.lowercased(),
                identifier,
            ].joined(separator: "\n")
            return CachedVideo(
                id: identifier,
                channelID: channelID,
                channelTitle: channelTitle,
                title: title,
                publishedAt: publishedAt,
                videoURL: URL(string: "https://www.youtube.com/watch?v=\(identifier)"),
                thumbnailRemoteURL: nil,
                thumbnailLocalFilename: nil,
                fetchedAt: savedAt,
                searchableText: searchableText,
                durationSeconds: nil,
                viewCount: nil
            )
        }
    }

    private static func sortCachedVideosDescending(lhs: CachedVideo, rhs: CachedVideo) -> Bool {
        switch (lhs.publishedAt, rhs.publishedAt) {
        case let (left?, right?) where left != right:
            return left > right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return lhs.fetchedAt > rhs.fetchedAt
        }
    }
}

private struct DiagnosticsProbe: View {
    @ObservedObject var diagnostics = StartupDiagnostics.shared
    @ObservedObject var runtimeDiagnostics = RuntimeDiagnostics.shared

    var body: some View {
        ZStack(alignment: .topLeading) {
            if AppLaunchMode.current.isUITest {
                Text("diagnostics")
                    .font(.caption2)
                    .foregroundStyle(.clear)
                    .accessibilityIdentifier("diagnostics.timeline")
                    .accessibilityValue(diagnostics.timelineValue)
            }

            if AppLaunchMode.current.isUITest {
                Text("runtime")
                    .font(.caption2)
                    .foregroundStyle(.clear)
                    .accessibilityIdentifier("diagnostics.runtimeLog")
                    .accessibilityValue(runtimeDiagnostics.latestValue)
            }
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

struct RenderProbe: UIViewRepresentable {
    let onMount: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isHidden = true
        DispatchQueue.main.async {
            onMount()
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
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

struct UITestAsyncActionTrigger: View {
    let identifier: String
    let action: () async -> Void

    var body: some View {
        if AppLaunchMode.current.usesMockData {
            Button {
                Task {
                    await action()
                }
            } label: {
                Image(systemName: "sparkle")
                    .font(.caption2)
                    .foregroundStyle(.clear)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(identifier)
        }
    }
}
