import Foundation

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

struct RemoteVideoSearchCacheSummary: Hashable {
    let keyword: String
    let totalCount: Int
    let fetchedAt: Date
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

nonisolated extension RemoteVideoSearchCacheSummary: Codable {}
nonisolated extension VideoSortOrder: Codable {}
nonisolated extension RemoteVideoSearchCacheEntry: Codable {}
