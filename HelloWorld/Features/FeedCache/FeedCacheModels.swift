import Foundation

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
    let durationSeconds: Int?
    let viewCount: Int?
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
    let registeredAt: Date?
    let latestVideo: CachedVideo?
    let cachedVideoCount: Int
}

struct VideoSearchResult: Hashable {
    let keyword: String
    let videos: [CachedVideo]
    let totalCount: Int
    let source: VideoSearchSource
    let fetchedAt: Date?
    let expiresAt: Date?
    let errorMessage: String?

    init(
        keyword: String,
        videos: [CachedVideo],
        totalCount: Int,
        source: VideoSearchSource = .localCache,
        fetchedAt: Date? = nil,
        expiresAt: Date? = nil,
        errorMessage: String? = nil
    ) {
        self.keyword = keyword
        self.videos = videos
        self.totalCount = totalCount
        self.source = source
        self.fetchedAt = fetchedAt
        self.expiresAt = expiresAt
        self.errorMessage = errorMessage
    }
}

enum VideoSearchSource: String, Hashable {
    case localCache
    case remoteAPI
    case remoteCache
    case staleRemoteCache
    case mockData

    var label: String {
        switch self {
        case .localCache:
            return "キャッシュ"
        case .remoteAPI:
            return "YouTube"
        case .remoteCache:
            return "検索キャッシュ"
        case .staleRemoteCache:
            return "古い検索キャッシュ"
        case .mockData:
            return "UIテスト"
        }
    }
}

struct RemoteVideoSearchCacheEntry: Hashable {
    let keyword: String
    let videos: [CachedVideo]
    let totalCount: Int
    let fetchedAt: Date
}

struct RemoteSearchCacheStatus: Hashable {
    let keyword: String
    let isFresh: Bool
    let totalCount: Int
    let fetchedAt: Date?
    let expiresAt: Date?
    let exists: Bool

    nonisolated static func empty(keyword: String) -> RemoteSearchCacheStatus {
        RemoteSearchCacheStatus(keyword: keyword, isFresh: false, totalCount: 0, fetchedAt: nil, expiresAt: nil, exists: false)
    }

    var label: String {
        guard exists else { return "未作成" }
        return isFresh ? "有効" : "期限切れ"
    }
}

struct HomeSystemStatus: Hashable {
    let registeredChannelCount: Int
    let cachedVideoCount: Int
    let cachedThumbnailBytes: Int64
    let cacheLastUpdatedAt: Date?
    let apiKeyConfigured: Bool
    let searchCacheStatus: RemoteSearchCacheStatus

    nonisolated static func empty(keyword: String) -> HomeSystemStatus {
        HomeSystemStatus(
            registeredChannelCount: 0,
            cachedVideoCount: 0,
            cachedThumbnailBytes: 0,
            cacheLastUpdatedAt: nil,
            apiKeyConfigured: false,
            searchCacheStatus: .empty(keyword: keyword)
        )
    }
}

enum ChannelRegistrationStatus: Hashable {
    case added
    case alreadyRegistered
}

struct ChannelRegistrationFeedback: Hashable {
    let status: ChannelRegistrationStatus
    let channelID: String
    let channelTitle: String
    let latestVideoTitle: String?
    let latestPublishedAt: Date?
    let cachedVideoCount: Int
    let latestFeedError: String?
}

struct ChannelRemovalFeedback: Identifiable, Hashable {
    let channelID: String
    let channelTitle: String
    let removedVideoCount: Int
    let removedThumbnailCount: Int

    var id: String { channelID }

    var title: String {
        "チャンネルを削除しました"
    }

    var detail: String {
        "\(channelTitle) を削除し、動画 \(removedVideoCount) 件・サムネイル \(removedThumbnailCount) 件を整理"
    }
}

struct CacheConsistencyMaintenanceResult: Hashable {
    let removedVideoCount: Int
    let removedThumbnailCount: Int
}

struct LocalStateResetFeedback: Hashable {
    let removedChannelCount: Int
    let removedVideoCount: Int
    let removedThumbnailCount: Int
    let removedSearchCacheCount: Int

    var title: String {
        "全設定をリセットしました"
    }

    var detail: String {
        "チャンネル \(removedChannelCount) 件、動画 \(removedVideoCount) 件、サムネイル \(removedThumbnailCount) 件、検索履歴 \(removedSearchCacheCount) 件を削除"
    }
}

enum ChannelRegistryTransferAction: Hashable {
    case export
    case `import`
}

struct ChannelRegistryTransferFeedback: Hashable {
    let action: ChannelRegistryTransferAction
    let backend: ChannelRegistryTransferBackend
    let channelCount: Int
    let path: String
    let refreshMessage: String?

    var title: String {
        switch action {
        case .export:
            return "バックアップを書き出しました"
        case .import:
            return "バックアップを読み込みました"
        }
    }

    var detail: String {
        switch action {
        case .export:
            return "\(backend.shortLabel)へチャンネル \(channelCount) 件を保存"
        case .import:
            return "\(backend.shortLabel)からチャンネル \(channelCount) 件を反映"
        }
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
nonisolated extension VideoSortOrder: Codable {}
nonisolated extension RemoteVideoSearchCacheEntry: Codable {}
