import Foundation

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

    static func channelRegistryURL(fileManager: FileManager = .default) -> URL {
        baseDirectory(fileManager: fileManager).appendingPathComponent("channel-registry.json")
    }
}

struct CachedVideo: Identifiable, Hashable {
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

struct CachedChannelState: Hashable {
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

struct FeedCacheSnapshot {
    var savedAt: Date
    var channels: [CachedChannelState]
    var videos: [CachedVideo]

    nonisolated static let empty = FeedCacheSnapshot(savedAt: .distantPast, channels: [], videos: [])
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

struct RefreshStageProgress: Hashable {
    let title: String
    let completed: Int
    let total: Int
    let activeCalls: Int
    let callsPerSecond: Int

    nonisolated static func idle(title: String, callsPerSecond: Int) -> RefreshStageProgress {
        RefreshStageProgress(title: title, completed: 0, total: 0, activeCalls: 0, callsPerSecond: callsPerSecond)
    }
}

struct CacheRefreshProgress: Hashable {
    var isRefreshing: Bool
    var checkStage: RefreshStageProgress
    var fetchStage: RefreshStageProgress
    var thumbnailStage: RefreshStageProgress

    nonisolated static let idle = CacheRefreshProgress(
        isRefreshing: false,
        checkStage: .idle(title: "フィード更新確認", callsPerSecond: 3),
        fetchStage: .idle(title: "更新チャンネル取得", callsPerSecond: 1),
        thumbnailStage: .idle(title: "サムネイル取得", callsPerSecond: 1)
    )
}

enum ChannelFreshness: String {
    case neverFetched
    case fresh
    case stale

    var label: String {
        switch self {
        case .neverFetched: return "未取得"
        case .fresh: return "最新"
        case .stale: return "未更新"
        }
    }
}

struct ChannelMaintenanceItem: Identifiable, Hashable {
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

struct FeedBootstrapSnapshot {
    var progress: CacheProgress
    var maintenanceItems: [ChannelMaintenanceItem]
}

struct ChannelRegistrySnapshot: Codable {
    var customChannelIDs: [String]
}

enum FeedBootstrapStore {
    static func load(channels: [String], fileManager: FileManager = .default) -> FeedBootstrapSnapshot {
        let url = FeedCachePaths.bootstrapURL(fileManager: fileManager)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = try? Data(contentsOf: url), let snapshot = try? decoder.decode(FeedBootstrapSnapshot.self, from: data) {
            return merged(snapshot: snapshot, channels: channels)
        }

        return merged(
            snapshot: FeedBootstrapSnapshot(
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
            ),
            channels: channels
        )
    }

    private static func merged(snapshot: FeedBootstrapSnapshot, channels: [String]) -> FeedBootstrapSnapshot {
        let existingItems = Dictionary(uniqueKeysWithValues: snapshot.maintenanceItems.map { ($0.channelID, $0) })
        let mergedItems = channels.map { channelID in
            existingItems[channelID] ?? ChannelMaintenanceItem(
                id: channelID,
                channelID: channelID,
                channelTitle: nil,
                lastSuccessAt: nil,
                lastCheckedAt: nil,
                latestPublishedAt: nil,
                cachedVideoCount: 0,
                lastError: nil,
                freshness: .neverFetched
            )
        }

        let currentChannelID = snapshot.progress.currentChannelID.flatMap { channels.contains($0) ? $0 : nil }
        let currentChannelNumber = currentChannelID.flatMap { channelID in
            channels.firstIndex(of: channelID).map { $0 + 1 }
        }

        return FeedBootstrapSnapshot(
            progress: CacheProgress(
                totalChannels: channels.count,
                cachedChannels: min(snapshot.progress.cachedChannels, channels.count),
                cachedVideos: snapshot.progress.cachedVideos,
                cachedThumbnails: snapshot.progress.cachedThumbnails,
                currentChannelID: currentChannelID,
                currentChannelNumber: currentChannelNumber,
                lastUpdatedAt: snapshot.progress.lastUpdatedAt,
                isRunning: snapshot.progress.isRunning,
                lastError: snapshot.progress.lastError
            ),
            maintenanceItems: mergedItems
        )
    }
}

enum ChannelRegistryStore {
    static func loadAllChannelIDs(bundle: Bundle = .main, fileManager: FileManager = .default) -> [String] {
        let bundledChannelIDs = ChannelResource.loadChannelIDs(bundle: bundle)
        let customChannelIDs = loadCustomChannelIDs(fileManager: fileManager)
        return uniqueChannelIDs(bundledChannelIDs + customChannelIDs)
    }

    static func addChannelID(_ channelID: String, fileManager: FileManager = .default) throws -> Bool {
        let normalizedChannelID = channelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedChannelID.isEmpty else { return false }

        let bundledChannelIDs = Set(ChannelResource.loadChannelIDs())
        if bundledChannelIDs.contains(normalizedChannelID) {
            return false
        }

        var snapshot = loadSnapshot(fileManager: fileManager)
        guard !snapshot.customChannelIDs.contains(normalizedChannelID) else {
            return false
        }

        snapshot.customChannelIDs.append(normalizedChannelID)
        snapshot.customChannelIDs = uniqueChannelIDs(snapshot.customChannelIDs)
        try persist(snapshot: snapshot, fileManager: fileManager)
        return true
    }

    private static func loadCustomChannelIDs(fileManager: FileManager) -> [String] {
        loadSnapshot(fileManager: fileManager).customChannelIDs
    }

    private static func loadSnapshot(fileManager: FileManager) -> ChannelRegistrySnapshot {
        let url = FeedCachePaths.channelRegistryURL(fileManager: fileManager)
        guard
            let data = try? Data(contentsOf: url),
            let snapshot = try? JSONDecoder().decode(ChannelRegistrySnapshot.self, from: data)
        else {
            return ChannelRegistrySnapshot(customChannelIDs: [])
        }

        return snapshot
    }

    private static func persist(snapshot: ChannelRegistrySnapshot, fileManager: FileManager) throws {
        let baseDirectory = FeedCachePaths.baseDirectory(fileManager: fileManager)
        try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: FeedCachePaths.channelRegistryURL(fileManager: fileManager), options: .atomic)
    }

    private static func uniqueChannelIDs(_ channelIDs: [String]) -> [String] {
        var seen = Set<String>()
        return channelIDs.filter { seen.insert($0).inserted }
    }
}

enum VideoSortOrder: String, CaseIterable {
    case publishedDescending
}

struct VideoQuery: Hashable {
    var limit: Int = 50
    var channelID: String?
    var keyword: String?
    var sortOrder: VideoSortOrder = .publishedDescending
    var excludeShorts: Bool = true
}

nonisolated extension CachedVideo: Codable {}
nonisolated extension CachedChannelState: Codable {}
nonisolated extension FeedCacheSnapshot: Codable {}
nonisolated extension CacheProgress: Codable {}
nonisolated extension RefreshStageProgress: Codable {}
nonisolated extension CacheRefreshProgress: Codable {}
nonisolated extension ChannelFreshness: Codable {}
nonisolated extension ChannelMaintenanceItem: Codable {}
nonisolated extension FeedBootstrapSnapshot: Codable {}
nonisolated extension VideoSortOrder: Codable {}
