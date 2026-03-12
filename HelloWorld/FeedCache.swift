import Foundation
import SwiftUI
import Combine

enum FeedCachePaths {
    static func baseDirectory(fileManager: FileManager = .default) -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return appSupport.appendingPathComponent("FeedCache", isDirectory: true)
    }

    static func thumbnailsDirectory(fileManager: FileManager = .default) -> URL {
        baseDirectory(fileManager: fileManager).appendingPathComponent("thumbnails", isDirectory: true)
    }

    static func thumbnailURL(filename: String, fileManager: FileManager = .default) -> URL {
        thumbnailsDirectory(fileManager: fileManager).appendingPathComponent(filename)
    }

    static func bootstrapURL(fileManager: FileManager = .default) -> URL {
        baseDirectory(fileManager: fileManager).appendingPathComponent("maintenance-bootstrap.json")
    }

    static func cacheURL(fileManager: FileManager = .default) -> URL {
        baseDirectory(fileManager: fileManager).appendingPathComponent("cache.json")
    }
}

struct CachedVideo: Codable, Identifiable, Hashable {
    let id: String
    let channelID: String
    let channelTitle: String
    let title: String
    let publishedAt: Date?
    let videoURL: URL?
    let thumbnailRemoteURL: URL?
    let thumbnailLocalFilename: String?
    let fetchedAt: Date
    let searchableText: String
}

struct CachedChannelState: Codable, Hashable {
    let channelID: String
    var channelTitle: String?
    var lastAttemptAt: Date?
    var lastCheckedAt: Date?
    var lastSuccessAt: Date?
    var latestPublishedAt: Date?
    var cachedVideoCount: Int
    var lastError: String?
    var etag: String?
    var lastModified: String?
}

struct FeedCacheSnapshot: Codable {
    var savedAt: Date
    var channels: [CachedChannelState]
    var videos: [CachedVideo]

    static let empty = FeedCacheSnapshot(savedAt: .distantPast, channels: [], videos: [])
}

struct CacheProgress: Codable {
    let totalChannels: Int
    let cachedChannels: Int
    let cachedVideos: Int
    let cachedThumbnails: Int
    let currentChannelID: String?
    let currentChannelNumber: Int?
    let lastUpdatedAt: Date?
    let isRunning: Bool
    let lastError: String?
}

enum ChannelFreshness: String, Codable {
    case neverFetched
    case fresh
    case stale

    var label: String {
        switch self {
        case .neverFetched:
            return "未取得"
        case .fresh:
            return "最新"
        case .stale:
            return "未更新"
        }
    }
}

struct ChannelMaintenanceItem: Codable, Identifiable, Hashable {
    let id: String
    let channelID: String
    let channelTitle: String?
    let lastSuccessAt: Date?
    let lastCheckedAt: Date?
    let latestPublishedAt: Date?
    let cachedVideoCount: Int
    let lastError: String?
    let freshness: ChannelFreshness
}

struct ChannelBrowseItem: Identifiable, Hashable {
    let id: String
    let channelID: String
    let channelTitle: String
    let latestPublishedAt: Date?
    let latestVideo: CachedVideo?
    let cachedVideoCount: Int
}

struct FeedBootstrapSnapshot: Codable {
    var progress: CacheProgress
    var maintenanceItems: [ChannelMaintenanceItem]
}

enum FeedBootstrapStore {
    static func load(channels: [String], fileManager: FileManager = .default) -> FeedBootstrapSnapshot {
        let url = FeedCachePaths.bootstrapURL(fileManager: fileManager)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if
            let data = try? Data(contentsOf: url),
            let snapshot = try? decoder.decode(FeedBootstrapSnapshot.self, from: data)
        {
            return snapshot
        }

        return FeedBootstrapSnapshot(
            progress: CacheProgress(
                totalChannels: channels.count,
                cachedChannels: 0,
                cachedVideos: 0,
                cachedThumbnails: 0,
                currentChannelID: nil,
                currentChannelNumber: nil,
                lastUpdatedAt: nil,
                isRunning: false,
                lastError: nil
            ),
            maintenanceItems: channels.map {
                ChannelMaintenanceItem(
                    id: $0,
                    channelID: $0,
                    channelTitle: nil,
                    lastSuccessAt: nil,
                    lastCheckedAt: nil,
                    latestPublishedAt: nil,
                    cachedVideoCount: 0,
                    lastError: nil,
                    freshness: .neverFetched
                )
            }
        )
    }
}

enum VideoSortOrder: String, Codable, CaseIterable {
    case publishedDescending
}

struct VideoQuery: Hashable {
    var limit: Int = 50
    var channelID: String?
    var keyword: String?
    var sortOrder: VideoSortOrder = .publishedDescending
    var excludeShorts: Bool = true
}

actor FeedCacheStore {
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private let baseDirectory: URL
    private let cacheFileURL: URL
    private let bootstrapFileURL: URL
    private let thumbnailsDirectory: URL

    init() {
        let appSupportURLs = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = appSupportURLs.first ?? FileManager.default.temporaryDirectory
        baseDirectory = appSupport.appendingPathComponent("FeedCache", isDirectory: true)
        cacheFileURL = baseDirectory.appendingPathComponent("cache.json")
        bootstrapFileURL = baseDirectory.appendingPathComponent("maintenance-bootstrap.json")
        thumbnailsDirectory = baseDirectory.appendingPathComponent("thumbnails", isDirectory: true)
    }

    func loadSnapshot() -> FeedCacheSnapshot {
        try? createDirectories()

        guard
            let data = try? Data(contentsOf: cacheFileURL),
            let snapshot = try? decoder.decode(FeedCacheSnapshot.self, from: data)
        else {
            return .empty
        }

        return snapshot
    }

    func loadVideos(query: VideoQuery) -> [CachedVideo] {
        let snapshot = loadSnapshot()

        return snapshot.videos
            .filter { video in
                let matchesChannel = query.channelID.map { video.channelID == $0 } ?? true
                let matchesKeyword = query.keyword.map { keyword in
                    video.searchableText.contains(keyword.lowercased())
                } ?? true
                let matchesShorts = query.excludeShorts ? !looksLikeShort(video) : true
                return matchesChannel && matchesKeyword && matchesShorts
            }
            .sorted(by: sortComparator(query.sortOrder))
            .prefix(query.limit)
            .map { $0 }
    }

    func loadChannelBrowseItems(channelIDs: [String]) -> [ChannelBrowseItem] {
        let snapshot = loadSnapshot()
        let groupedVideos = Dictionary(grouping: snapshot.videos.filter { !looksLikeShort($0) }, by: \.channelID)
        let states = Dictionary(uniqueKeysWithValues: snapshot.channels.map { ($0.channelID, $0) })

        return channelIDs.map { channelID in
            let latestVideo = groupedVideos[channelID]?
                .sorted(by: sortComparator(.publishedDescending))
                .first
            let state = states[channelID]
            return ChannelBrowseItem(
                id: channelID,
                channelID: channelID,
                channelTitle: state?.channelTitle ?? latestVideo?.channelTitle ?? channelID,
                latestPublishedAt: state?.latestPublishedAt ?? latestVideo?.publishedAt,
                latestVideo: latestVideo,
                cachedVideoCount: state?.cachedVideoCount ?? groupedVideos[channelID]?.count ?? 0
            )
        }
        .sorted { lhs, rhs in
            switch (lhs.latestPublishedAt, rhs.latestPublishedAt) {
            case let (left?, right?):
                return left > right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return lhs.channelTitle < rhs.channelTitle
            }
        }
    }

    func recordFailure(channelID: String, checkedAt: Date, error: String) {
        var snapshot = loadSnapshot()
        var channel = snapshot.channels.first(where: { $0.channelID == channelID })
            ?? CachedChannelState(
                channelID: channelID,
                channelTitle: nil,
                lastAttemptAt: nil,
                lastCheckedAt: nil,
                lastSuccessAt: nil,
                latestPublishedAt: nil,
                cachedVideoCount: 0,
                lastError: nil,
                etag: nil,
                lastModified: nil
            )
        channel.lastAttemptAt = checkedAt
        channel.lastCheckedAt = checkedAt
        channel.lastError = error
        upsert(channel: channel, into: &snapshot.channels)
        snapshot.savedAt = checkedAt
        persist(snapshot)
    }

    func recordNotModified(channelID: String, metadata: FeedFetchMetadata) {
        var snapshot = loadSnapshot()
        var channel = snapshot.channels.first(where: { $0.channelID == channelID })
            ?? CachedChannelState(
                channelID: channelID,
                channelTitle: nil,
                lastAttemptAt: nil,
                lastCheckedAt: nil,
                lastSuccessAt: nil,
                latestPublishedAt: nil,
                cachedVideoCount: 0,
                lastError: nil,
                etag: nil,
                lastModified: nil
            )
        channel.lastAttemptAt = metadata.checkedAt
        channel.lastCheckedAt = metadata.checkedAt
        channel.lastError = nil
        channel.etag = metadata.validationToken.etag
        channel.lastModified = metadata.validationToken.lastModified
        upsert(channel: channel, into: &snapshot.channels)
        snapshot.savedAt = metadata.checkedAt
        persist(snapshot)
    }

    func recordSuccess(channelID: String, videos: [YouTubeVideo], metadata: FeedFetchMetadata) async {
        var snapshot = loadSnapshot()
        let fetchedAt = metadata.checkedAt

        snapshot.videos.removeAll { $0.channelID == channelID }
        var cachedVideosByID = Dictionary(uniqueKeysWithValues: snapshot.videos.map { ($0.id, $0) })

        for video in videos {
            let channelTitle = video.channelTitle.isEmpty ? (cachedVideosByID[video.id]?.channelTitle ?? "") : video.channelTitle
            cachedVideosByID[video.id] = CachedVideo(
                id: video.id,
                channelID: channelID,
                channelTitle: channelTitle,
                title: video.title,
                publishedAt: video.publishedAt,
                videoURL: video.videoURL,
                thumbnailRemoteURL: video.thumbnailURL,
                thumbnailLocalFilename: cachedVideosByID[video.id]?.thumbnailLocalFilename,
                fetchedAt: fetchedAt,
                searchableText: [video.title, channelTitle, video.id]
                    .joined(separator: "\n")
                    .lowercased()
            )
        }

        snapshot.videos = cachedVideosByID.values.sorted {
            switch ($0.publishedAt, $1.publishedAt) {
            case let (left?, right?):
                return left > right
            case (_?, nil):
                return true
            default:
                return $0.fetchedAt > $1.fetchedAt
            }
        }

        let resolvedChannelTitle = videos.first(where: { !$0.channelTitle.isEmpty })?.channelTitle
        let latestPublishedAt = videos.compactMap(\.publishedAt).max()
        let channelVideoCount = snapshot.videos.filter { $0.channelID == channelID }.count

        var channel = snapshot.channels.first(where: { $0.channelID == channelID })
            ?? CachedChannelState(
                channelID: channelID,
                channelTitle: nil,
                lastAttemptAt: nil,
                lastCheckedAt: nil,
                lastSuccessAt: nil,
                latestPublishedAt: nil,
                cachedVideoCount: 0,
                lastError: nil,
                etag: nil,
                lastModified: nil
            )
        channel.channelTitle = resolvedChannelTitle ?? channel.channelTitle
        channel.lastAttemptAt = fetchedAt
        channel.lastCheckedAt = fetchedAt
        channel.lastSuccessAt = fetchedAt
        channel.latestPublishedAt = latestPublishedAt ?? channel.latestPublishedAt
        channel.cachedVideoCount = channelVideoCount
        channel.lastError = nil
        channel.etag = metadata.validationToken.etag
        channel.lastModified = metadata.validationToken.lastModified
        upsert(channel: channel, into: &snapshot.channels)

        snapshot.savedAt = fetchedAt
        persist(snapshot)
    }

    func cacheThumbnails(for videos: [YouTubeVideo]) async {
        guard !videos.isEmpty else { return }

        var snapshot = loadSnapshot()
        var didUpdate = false

        for video in videos {
            guard let localThumbnailFilename = await cacheThumbnailIfNeeded(from: video.thumbnailURL, videoID: video.id) else {
                continue
            }

            guard let index = snapshot.videos.firstIndex(where: { $0.id == video.id }) else {
                continue
            }

            if snapshot.videos[index].thumbnailLocalFilename != localThumbnailFilename {
                let existing = snapshot.videos[index]
                snapshot.videos[index] = CachedVideo(
                    id: existing.id,
                    channelID: existing.channelID,
                    channelTitle: existing.channelTitle,
                    title: existing.title,
                    publishedAt: existing.publishedAt,
                    videoURL: existing.videoURL,
                    thumbnailRemoteURL: existing.thumbnailRemoteURL,
                    thumbnailLocalFilename: localThumbnailFilename,
                    fetchedAt: existing.fetchedAt,
                    searchableText: existing.searchableText
                )
                didUpdate = true
            }
        }

        if didUpdate {
            snapshot.savedAt = .now
            persist(snapshot)
        }
    }

    private func cacheThumbnailIfNeeded(from remoteURL: URL?, videoID: String) async -> String? {
        guard let remoteURL else { return nil }

        try? createDirectories()

        let ext = remoteURL.pathExtension.isEmpty ? "jpg" : remoteURL.pathExtension
        let filename = "\(videoID).\(ext)"
        let localURL = thumbnailsDirectory.appendingPathComponent(filename)

        if fileManager.fileExists(atPath: localURL.path) {
            return filename
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: remoteURL)
            try data.write(to: localURL, options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    private func persist(_ snapshot: FeedCacheSnapshot) {
        try? createDirectories()

        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: cacheFileURL, options: .atomic)
    }

    func persistBootstrap(progress: CacheProgress, maintenanceItems: [ChannelMaintenanceItem]) {
        try? createDirectories()

        let bootstrap = FeedBootstrapSnapshot(progress: progress, maintenanceItems: maintenanceItems)
        guard let data = try? encoder.encode(bootstrap) else { return }
        try? data.write(to: bootstrapFileURL, options: .atomic)
    }

    private func sortComparator(_ order: VideoSortOrder) -> (CachedVideo, CachedVideo) -> Bool {
        switch order {
        case .publishedDescending:
            return { lhs, rhs in
                switch (lhs.publishedAt, rhs.publishedAt) {
                case let (left?, right?):
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
    }

    private func looksLikeShort(_ video: CachedVideo) -> Bool {
        if let videoURL = video.videoURL?.absoluteString.lowercased(), videoURL.contains("/shorts/") {
            return true
        }

        let title = video.title.lowercased()
        return title.contains("#shorts") || title.hasPrefix("shorts")
    }

    private func upsert(channel: CachedChannelState, into channels: inout [CachedChannelState]) {
        if let index = channels.firstIndex(where: { $0.channelID == channel.channelID }) {
            channels[index] = channel
        } else {
            channels.append(channel)
        }
    }

    private func createDirectories() throws {
        try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
    }
}

@MainActor
final class FeedCacheCoordinator: ObservableObject {
    @Published private(set) var progress: CacheProgress
    @Published private(set) var maintenanceItems: [ChannelMaintenanceItem] = []
    @Published private(set) var videos: [CachedVideo] = []

    private let channels: [String]
    private let store = FeedCacheStore()
    private let feedService = YouTubeFeedService()
    private var refreshTask: Task<Void, Never>?
    private let freshnessInterval: TimeInterval
    private let hourlyCheckInterval: TimeInterval = 60 * 60
    private let firstDailySweepInterval: TimeInterval = 10
    private var videoQuery = VideoQuery()
    private var liveUpdateSuspendCount = 0
    private var needsRefreshWhenResumed = false

    init(channels: [String], freshnessInterval: TimeInterval? = nil) {
        self.channels = channels
        self.freshnessInterval = freshnessInterval ?? TimeInterval(max(channels.count, 1) * 60)
        let bootstrap = FeedBootstrapStore.load(channels: channels)
        self.progress = bootstrap.progress
        self.maintenanceItems = bootstrap.maintenanceItems
    }

    func bootstrapMaintenance() async {
        let bootstrap = FeedBootstrapStore.load(channels: channels)
        progress = bootstrap.progress
        maintenanceItems = bootstrap.maintenanceItems
    }

    func suspendLiveUpdates() {
        liveUpdateSuspendCount += 1
    }

    func resumeLiveUpdates() {
        liveUpdateSuspendCount = max(liveUpdateSuspendCount - 1, 0)

        guard liveUpdateSuspendCount == 0, needsRefreshWhenResumed else { return }
        needsRefreshWhenResumed = false
        refreshMaintenanceFromCache()
    }

    func start() {
        guard refreshTask == nil else { return }

        refreshTask = Task {
            await refreshUI(currentChannelID: nil, isRunning: true, lastError: nil)

            while !Task.isCancelled {
                let cycleStartedAt = Date()
                let plan = await nextRefreshPlan()

                guard !channels.isEmpty else {
                    await refreshUI(currentChannelID: nil, isRunning: false, lastError: "チャンネル一覧が空です。")
                    return
                }

                guard let nextChannelID = plan.channelID else {
                    do {
                        try await Task.sleep(for: .seconds(plan.delayUntilNextCheck))
                    } catch {
                        return
                    }
                    continue
                }

                do {
                    await refreshUI(currentChannelID: nextChannelID, isRunning: true, lastError: nil)
                    let validationToken = await channelValidationToken(for: nextChannelID)
                    let result = try await feedService.fetchIfNeeded(for: nextChannelID, validationToken: validationToken)

                    switch result {
                    case let .notModified(metadata):
                        await store.recordNotModified(channelID: nextChannelID, metadata: metadata)
                        await refreshUI(currentChannelID: nextChannelID, isRunning: true, lastError: nil)
                    case let .updated(videos, metadata):
                        await store.recordSuccess(channelID: nextChannelID, videos: videos, metadata: metadata)
                        await refreshUI(currentChannelID: nextChannelID, isRunning: true, lastError: nil)
                        Task { [store] in
                            await store.cacheThumbnails(for: videos)
                            refreshMaintenanceFromCache()
                            loadVideosFromCache()
                        }
                    }
                } catch {
                    await store.recordFailure(channelID: nextChannelID, checkedAt: .now, error: error.localizedDescription)
                    await refreshUI(currentChannelID: nextChannelID, isRunning: true, lastError: "取得失敗: \(nextChannelID)")
                }

                do {
                    let elapsed = Date().timeIntervalSince(cycleStartedAt)
                    let remaining = max(plan.delayUntilNextCheck - elapsed, 0.2)
                    try await Task.sleep(for: .seconds(remaining))
                } catch {
                    return
                }
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil

        Task {
            await refreshUI(currentChannelID: nil, isRunning: false, lastError: progress.lastError)
        }
    }

    func refreshMaintenanceFromCache() {
        Task {
            await refreshUI(
                currentChannelID: progress.currentChannelID,
                isRunning: refreshTask != nil,
                lastError: progress.lastError,
                includesVideos: false
            )
        }
    }

    func loadVideosFromCache() {
        Task {
            videos = await store.loadVideos(query: videoQuery)
        }
    }

    func loadPriorityMaintenanceFromCache() {
        Task {
            let snapshot = await store.loadSnapshot()
            let items = await buildMaintenanceItems(from: snapshot)
            await store.persistBootstrap(progress: progress, maintenanceItems: items)
        }
    }

    func loadChannelBrowseItems() async -> [ChannelBrowseItem] {
        let channelIDs = maintenanceItems.map(\.channelID).isEmpty ? channels : maintenanceItems.map(\.channelID)
        return await store.loadChannelBrowseItems(channelIDs: channelIDs)
    }

    func loadVideosForChannel(_ channelID: String) async -> [CachedVideo] {
        await store.loadVideos(query: VideoQuery(limit: 50, channelID: channelID, keyword: nil, sortOrder: .publishedDescending, excludeShorts: true))
    }

    private func channelValidationToken(for channelID: String) async -> FeedValidationToken? {
        let snapshot = await store.loadSnapshot()
        guard let state = snapshot.channels.first(where: { $0.channelID == channelID }) else {
            return nil
        }

        return FeedValidationToken(etag: state.etag, lastModified: state.lastModified)
    }

    private func nextRefreshPlan() async -> RefreshPlan {
        let snapshot = await store.loadSnapshot()
        let states = Dictionary(uniqueKeysWithValues: snapshot.channels.map { ($0.channelID, $0) })
        let sortedChannels = prioritizedChannelIDs(states: states)

        let firstDailyTargets = sortedChannels.filter { channelID in
            guard let lastCheckedAt = states[channelID]?.lastCheckedAt else {
                return true
            }
            return !Calendar.current.isDateInToday(lastCheckedAt)
        }
        if let channelID = firstDailyTargets.first {
            return RefreshPlan(channelID: channelID, delayUntilNextCheck: firstDailySweepInterval)
        }

        let dueChannels = sortedChannels.filter { channelID in
            guard let lastCheckedAt = states[channelID]?.lastCheckedAt else {
                return true
            }
            return Date().timeIntervalSince(lastCheckedAt) >= hourlyCheckInterval
        }
        if let channelID = dueChannels.first {
            return RefreshPlan(channelID: channelID, delayUntilNextCheck: hourlyCheckInterval)
        }

        let nextDelay = sortedChannels
            .compactMap { channelID -> TimeInterval? in
                guard let lastCheckedAt = states[channelID]?.lastCheckedAt else {
                    return 0
                }
                let elapsed = Date().timeIntervalSince(lastCheckedAt)
                return max(hourlyCheckInterval - elapsed, 5)
            }
            .min() ?? hourlyCheckInterval

        return RefreshPlan(channelID: nil, delayUntilNextCheck: nextDelay)
    }

    private func prioritizedChannelIDs(states: [String: CachedChannelState]) -> [String] {
        FeedOrdering.prioritizedChannelIDs(channels: channels, states: states)
    }

    private func refreshUI(currentChannelID: String?, isRunning: Bool, lastError: String?, includesVideos: Bool = true) async {
        let snapshot = await store.loadSnapshot()
        let cachedChannels = snapshot.channels.filter { $0.lastSuccessAt != nil }.count
        let cachedThumbnails = snapshot.videos.filter { $0.thumbnailLocalFilename != nil }.count
        let prioritizedChannels = prioritizedChannelIDs(states: Dictionary(uniqueKeysWithValues: snapshot.channels.map { ($0.channelID, $0) }))
        let currentChannelNumber = currentChannelID.flatMap { prioritizedChannels.firstIndex(of: $0) }.map { $0 + 1 }
        let nextProgress = CacheProgress(
            totalChannels: channels.count,
            cachedChannels: cachedChannels,
            cachedVideos: snapshot.videos.count,
            cachedThumbnails: cachedThumbnails,
            currentChannelID: currentChannelID,
            currentChannelNumber: currentChannelNumber,
            lastUpdatedAt: snapshot.savedAt == .distantPast ? nil : snapshot.savedAt,
            isRunning: isRunning,
            lastError: lastError
        )
        let nextMaintenanceItems = await buildMaintenanceItems(from: snapshot)

        if liveUpdateSuspendCount > 0 {
            needsRefreshWhenResumed = true
            return
        }

        progress = nextProgress
        maintenanceItems = nextMaintenanceItems

        await store.persistBootstrap(progress: progress, maintenanceItems: maintenanceItems)

        if includesVideos {
            videos = await store.loadVideos(query: videoQuery)
        }
    }

    private func buildMaintenanceItems(from snapshot: FeedCacheSnapshot) async -> [ChannelMaintenanceItem] {
        let prioritizedChannels = prioritizedChannelIDs(states: Dictionary(uniqueKeysWithValues: snapshot.channels.map { ($0.channelID, $0) }))
        return prioritizedChannels.map { channelID in
            let state = snapshot.channels.first(where: { $0.channelID == channelID })
            return ChannelMaintenanceItem(
                id: channelID,
                channelID: channelID,
                channelTitle: state?.channelTitle,
                lastSuccessAt: state?.lastSuccessAt,
                lastCheckedAt: state?.lastCheckedAt,
                latestPublishedAt: state?.latestPublishedAt,
                cachedVideoCount: state?.cachedVideoCount ?? 0,
                lastError: state?.lastError,
                freshness: freshness(for: state?.lastSuccessAt)
            )
        }
    }

    private func freshness(for lastSuccessAt: Date?) -> ChannelFreshness {
        FeedOrdering.freshness(lastSuccessAt: lastSuccessAt, freshnessInterval: freshnessInterval)
    }
}

private struct RefreshPlan {
    let channelID: String?
    let delayUntilNextCheck: TimeInterval
}
