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

struct FeedCacheSummary: Hashable {
    let savedAt: Date?
    let cachedChannelCount: Int
    let cachedVideoCount: Int
    let cachedThumbnailBytes: Int64

    nonisolated static let empty = FeedCacheSummary(
        savedAt: nil,
        cachedChannelCount: 0,
        cachedVideoCount: 0,
        cachedThumbnailBytes: 0
    )
}

nonisolated extension CachedVideo: Codable {}
nonisolated extension CachedChannelState: Codable {}
nonisolated extension FeedCacheSnapshot: Codable {}
nonisolated extension FeedCacheSummary: Codable {}
