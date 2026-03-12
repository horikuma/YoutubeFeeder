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
    var lastSuccessAt: Date?
    var cachedVideoCount: Int
    var lastError: String?
}

struct FeedCacheSnapshot: Codable {
    var savedAt: Date
    var channels: [CachedChannelState]
    var videos: [CachedVideo]

    static let empty = FeedCacheSnapshot(savedAt: .distantPast, channels: [], videos: [])
}

struct CacheProgress {
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

struct ChannelMaintenanceItem: Identifiable, Hashable {
    let id: String
    let channelID: String
    let channelTitle: String?
    let lastSuccessAt: Date?
    let lastAttemptAt: Date?
    let cachedVideoCount: Int
    let lastError: String?
    let freshness: ChannelFreshness
}

enum VideoSortOrder: String, Codable, CaseIterable {
    case publishedDescending
}

struct VideoQuery: Hashable {
    var limit: Int = 50
    var channelID: String?
    var keyword: String?
    var sortOrder: VideoSortOrder = .publishedDescending
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
    private let thumbnailsDirectory: URL

    init() {
        let appSupportURLs = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = appSupportURLs.first ?? FileManager.default.temporaryDirectory
        baseDirectory = appSupport.appendingPathComponent("FeedCache", isDirectory: true)
        cacheFileURL = baseDirectory.appendingPathComponent("cache.json")
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
                return matchesChannel && matchesKeyword
            }
            .sorted(by: sortComparator(query.sortOrder))
            .prefix(query.limit)
            .map { $0 }
    }

    func recordFailure(channelID: String, error: String) {
        var snapshot = loadSnapshot()
        var channel = snapshot.channels.first(where: { $0.channelID == channelID })
            ?? CachedChannelState(channelID: channelID, channelTitle: nil, lastAttemptAt: nil, lastSuccessAt: nil, cachedVideoCount: 0, lastError: nil)
        channel.lastAttemptAt = .now
        channel.lastError = error
        upsert(channel: channel, into: &snapshot.channels)
        snapshot.savedAt = .now
        persist(snapshot)
    }

    func recordSuccess(channelID: String, videos: [YouTubeVideo]) async {
        var snapshot = loadSnapshot()
        let fetchedAt = Date()

        var cachedVideosByID = Dictionary(uniqueKeysWithValues: snapshot.videos.map { ($0.id, $0) })

        for video in videos {
            let localThumbnailFilename = await cacheThumbnailIfNeeded(from: video.thumbnailURL, videoID: video.id)
            let channelTitle = video.channelTitle.isEmpty ? (cachedVideosByID[video.id]?.channelTitle ?? "") : video.channelTitle
            cachedVideosByID[video.id] = CachedVideo(
                id: video.id,
                channelID: channelID,
                channelTitle: channelTitle,
                title: video.title,
                publishedAt: video.publishedAt,
                videoURL: video.videoURL,
                thumbnailRemoteURL: video.thumbnailURL,
                thumbnailLocalFilename: localThumbnailFilename ?? cachedVideosByID[video.id]?.thumbnailLocalFilename,
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
        let channelVideoCount = snapshot.videos.filter { $0.channelID == channelID }.count

        var channel = snapshot.channels.first(where: { $0.channelID == channelID })
            ?? CachedChannelState(channelID: channelID, channelTitle: nil, lastAttemptAt: nil, lastSuccessAt: nil, cachedVideoCount: 0, lastError: nil)
        channel.channelTitle = resolvedChannelTitle ?? channel.channelTitle
        channel.lastAttemptAt = fetchedAt
        channel.lastSuccessAt = fetchedAt
        channel.cachedVideoCount = channelVideoCount
        channel.lastError = nil
        upsert(channel: channel, into: &snapshot.channels)

        snapshot.savedAt = fetchedAt
        persist(snapshot)
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
    private var videoQuery = VideoQuery()

    init(channels: [String], freshnessInterval: TimeInterval? = nil) {
        self.channels = channels
        self.freshnessInterval = freshnessInterval ?? TimeInterval(max(channels.count, 1) * 60)
        self.progress = CacheProgress(
            totalChannels: channels.count,
            cachedChannels: 0,
            cachedVideos: 0,
            cachedThumbnails: 0,
            currentChannelID: nil,
            currentChannelNumber: nil,
            lastUpdatedAt: nil,
            isRunning: false,
            lastError: nil
        )
    }

    func start() {
        guard refreshTask == nil else { return }

        refreshTask = Task {
            await refreshUI(currentChannelID: nil, isRunning: true, lastError: nil)

            while !Task.isCancelled {
                let nextChannelID = await nextChannelToRefresh()

                guard let nextChannelID else {
                    await refreshUI(currentChannelID: nil, isRunning: false, lastError: "チャンネル一覧が空です。")
                    return
                }

                do {
                    await refreshUI(currentChannelID: nextChannelID, isRunning: true, lastError: nil)
                    let videos = try await feedService.fetchVideos(for: nextChannelID)
                    await store.recordSuccess(channelID: nextChannelID, videos: videos)
                    await refreshUI(currentChannelID: nextChannelID, isRunning: true, lastError: nil)
                } catch {
                    await store.recordFailure(channelID: nextChannelID, error: error.localizedDescription)
                    await refreshUI(currentChannelID: nextChannelID, isRunning: true, lastError: "取得失敗: \(nextChannelID)")
                }

                do {
                    try await Task.sleep(for: .seconds(60))
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

    func refreshFromCache() {
        Task {
            await refreshUI(currentChannelID: progress.currentChannelID, isRunning: refreshTask != nil, lastError: progress.lastError)
        }
    }

    private func nextChannelToRefresh() async -> String? {
        let snapshot = await store.loadSnapshot()
        let states = Dictionary(uniqueKeysWithValues: snapshot.channels.map { ($0.channelID, $0) })

        let neverFetched = channels.filter { states[$0]?.lastSuccessAt == nil }
        if let next = neverFetched.first {
            return next
        }

        return channels.min { lhs, rhs in
            let lhsDate = states[lhs]?.lastSuccessAt ?? .distantPast
            let rhsDate = states[rhs]?.lastSuccessAt ?? .distantPast
            return lhsDate < rhsDate
        }
    }

    private func refreshUI(currentChannelID: String?, isRunning: Bool, lastError: String?) async {
        let snapshot = await store.loadSnapshot()
        let cachedChannels = snapshot.channels.filter { $0.lastSuccessAt != nil }.count
        let cachedThumbnails = snapshot.videos.filter { $0.thumbnailLocalFilename != nil }.count
        let currentChannelNumber = currentChannelID.flatMap { channels.firstIndex(of: $0) }.map { $0 + 1 }

        progress = CacheProgress(
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

        maintenanceItems = channels.map { channelID in
            let state = snapshot.channels.first(where: { $0.channelID == channelID })
            return ChannelMaintenanceItem(
                id: channelID,
                channelID: channelID,
                channelTitle: state?.channelTitle,
                lastSuccessAt: state?.lastSuccessAt,
                lastAttemptAt: state?.lastAttemptAt,
                cachedVideoCount: state?.cachedVideoCount ?? 0,
                lastError: state?.lastError,
                freshness: freshness(for: state?.lastSuccessAt)
            )
        }

        videos = await store.loadVideos(query: videoQuery)
    }

    private func freshness(for lastSuccessAt: Date?) -> ChannelFreshness {
        guard let lastSuccessAt else {
            return .neverFetched
        }

        let age = Date().timeIntervalSince(lastSuccessAt)
        return age <= freshnessInterval ? .fresh : .stale
    }
}
