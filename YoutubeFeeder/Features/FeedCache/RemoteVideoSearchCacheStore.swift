import Foundation

actor RemoteVideoSearchCacheStore {
    private let database = FeedCacheSQLiteDatabase.shared()

    func load(keyword: String) -> RemoteVideoSearchCacheEntry? {
        database.loadRemoteSearchEntry(keyword: keyword)
    }

    func save(keyword: String, videos: [CachedVideo], totalCount: Int, fetchedAt: Date) {
        database.saveRemoteSearchEntry(
            RemoteVideoSearchCacheEntry(
            keyword: keyword,
            videos: videos,
            totalCount: totalCount,
            fetchedAt: fetchedAt
        )
        )
    }

    func merge(keyword: String, videos: [CachedVideo], fetchedAt: Date) {
        let existing = load(keyword: keyword)
        var mergedByID = Dictionary(
            (existing?.videos ?? []).map { ($0.id, $0) },
            uniquingKeysWith: { _, rhs in rhs }
        )
        for video in videos {
            mergedByID[video.id] = video
        }

        let mergedVideos = mergedByID.values.sorted { lhs, rhs in
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

        save(
            keyword: keyword,
            videos: mergedVideos,
            totalCount: mergedVideos.count,
            fetchedAt: fetchedAt
        )
    }

    func clear(keyword: String) {
        database.clearRemoteSearch(keyword: keyword)
    }

    func clearAll() -> Int {
        database.clearAllRemoteSearch()
    }

    func status(keyword: String, ttl: TimeInterval, now: Date = .now) -> RemoteSearchCacheStatus {
        guard let entry = load(keyword: keyword) else { return .empty(keyword: keyword) }

        let expiresAt = entry.fetchedAt.addingTimeInterval(ttl)
        return RemoteSearchCacheStatus(
            keyword: keyword,
            isFresh: expiresAt > now,
            totalCount: entry.totalCount,
            fetchedAt: entry.fetchedAt,
            expiresAt: expiresAt,
            exists: true
        )
    }

    func allVideos(channelID: String) -> [CachedVideo] {
        database.loadAllRemoteSearchVideos(channelID: channelID)
    }
}
