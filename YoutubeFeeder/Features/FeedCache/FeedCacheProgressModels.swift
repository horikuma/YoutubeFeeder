import Foundation

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

nonisolated extension CacheProgress: Codable {}
nonisolated extension RefreshStageProgress: Codable {}
nonisolated extension CacheRefreshProgress: Codable {}
