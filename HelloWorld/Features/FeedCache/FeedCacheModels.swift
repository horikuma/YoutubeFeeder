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

enum FeedBootstrapStore {
    static func load(channels: [String], fileManager: FileManager = .default) -> FeedBootstrapSnapshot {
        let url = FeedCachePaths.bootstrapURL(fileManager: fileManager)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = try? Data(contentsOf: url), let snapshot = try? decoder.decode(FeedBootstrapSnapshot.self, from: data) {
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
