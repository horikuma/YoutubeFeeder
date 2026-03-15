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

    func merge(keyword: String, videos: [CachedVideo], fetchedAt: Date) {
        let existing = load(keyword: keyword)
        var mergedByID = Dictionary(uniqueKeysWithValues: (existing?.videos ?? []).map { ($0.id, $0) })
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
        let fileURL = FeedCachePaths.remoteSearchCacheURL(keyword: keyword, fileManager: fileManager)
        try? fileManager.removeItem(at: fileURL)
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

    func allVideos(channelID: String) -> [CachedVideo] {
        let baseURL = FeedCachePaths.baseDirectory(fileManager: fileManager)
        let filenames = (try? fileManager.contentsOfDirectory(atPath: baseURL.path)) ?? []
        let urls = filenames
            .filter { $0.hasPrefix("remote-search-") && $0.hasSuffix(".json") }
            .map { baseURL.appendingPathComponent($0) }

        let entries: [RemoteVideoSearchCacheEntry] = urls.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(RemoteVideoSearchCacheEntry.self, from: data)
        }
        return entries.flatMap { $0.videos }.filter { $0.channelID == channelID }
    }
}
