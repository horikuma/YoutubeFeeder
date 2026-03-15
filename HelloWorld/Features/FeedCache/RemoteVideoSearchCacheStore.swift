import Foundation

actor RemoteVideoSearchCacheStore {
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

    func load(keyword: String) -> RemoteVideoSearchCacheEntry? {
        let fileURL = FeedCachePaths.remoteSearchCacheURL(keyword: keyword, fileManager: fileManager)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? decoder.decode(RemoteVideoSearchCacheEntry.self, from: data)
    }

    func save(keyword: String, videos: [CachedVideo], totalCount: Int, fetchedAt: Date) {
        try? fileManager.createDirectory(
            at: FeedCachePaths.baseDirectory(fileManager: fileManager),
            withIntermediateDirectories: true
        )
        let entry = RemoteVideoSearchCacheEntry(
            keyword: keyword,
            videos: videos,
            totalCount: totalCount,
            fetchedAt: fetchedAt
        )
        guard let data = try? encoder.encode(entry) else { return }
        let fileURL = FeedCachePaths.remoteSearchCacheURL(keyword: keyword, fileManager: fileManager)
        try? data.write(to: fileURL, options: .atomic)
    }

    func status(keyword: String, ttl: TimeInterval, now: Date = .now) -> RemoteSearchCacheStatus {
        guard let entry = load(keyword: keyword) else {
            return .empty(keyword: keyword)
        }

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
}
