import Foundation

actor RemoteVideoSearchCacheStore {
    private let fileManager = FileManager.default
    private let encoder = FeedCachePersistenceCoders.makeEncoder()
    private let decoder = FeedCachePersistenceCoders.makeDecoder()
    private let summaryEncoder = FeedCachePersistenceCoders.makeSummaryEncoder()
    private let summaryDecoder = FeedCachePersistenceCoders.makeSummaryDecoder()

    func load(keyword: String) -> RemoteVideoSearchCacheEntry? {
        let fileURL = FeedCachePaths.remoteSearchCacheURL(keyword: keyword, fileManager: fileManager)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let entry = try? decoder.decode(RemoteVideoSearchCacheEntry.self, from: data) else { return nil }
        persistSummary(for: entry)
        return entry
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
        persistSummary(for: entry)
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
        let summaryURL = FeedCachePaths.remoteSearchCacheSummaryURL(keyword: keyword, fileManager: fileManager)
        try? fileManager.removeItem(at: fileURL)
        try? fileManager.removeItem(at: summaryURL)
    }

    func clearAll() -> Int {
        let baseURL = FeedCachePaths.baseDirectory(fileManager: fileManager)
        let filenames = (try? fileManager.contentsOfDirectory(atPath: baseURL.path)) ?? []
        let targets = filenames.filter {
            (($0 == "remote-search.json" || $0.hasPrefix("remote-search-")) && $0.hasSuffix(".json")) && !$0.hasSuffix("-summary.plist")
        }
        for filename in targets {
            try? fileManager.removeItem(at: baseURL.appendingPathComponent(filename))
            if !filename.hasSuffix("-summary.plist") {
                let summaryFilename = filename.replacingOccurrences(of: ".json", with: "-summary.plist")
                try? fileManager.removeItem(at: baseURL.appendingPathComponent(summaryFilename))
            }
        }
        return targets.count
    }

    func status(keyword: String, ttl: TimeInterval, now: Date = .now) -> RemoteSearchCacheStatus {
        let fileURL = FeedCachePaths.remoteSearchCacheURL(keyword: keyword, fileManager: fileManager)

        let summaryURL = FeedCachePaths.remoteSearchCacheSummaryURL(keyword: keyword, fileManager: fileManager)
        if let summaryData = try? Data(contentsOf: summaryURL) {
            if let summary = try? summaryDecoder.decode(RemoteVideoSearchCacheSummary.self, from: summaryData) {
                let expiresAt = summary.fetchedAt.addingTimeInterval(ttl)
                return RemoteSearchCacheStatus(
                    keyword: keyword,
                    isFresh: expiresAt > now,
                    totalCount: summary.totalCount,
                    fetchedAt: summary.fetchedAt,
                    expiresAt: expiresAt,
                    exists: true
                )
            }
        }

        guard fileManager.fileExists(atPath: fileURL.path) else { return .empty(keyword: keyword) }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            return .empty(keyword: keyword)
        }

        let entry: RemoteVideoSearchCacheEntry
        do {
            entry = try decoder.decode(RemoteVideoSearchCacheEntry.self, from: data)
        } catch {
            return .empty(keyword: keyword)
        }
        persistSummary(for: entry)

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

    private func persistSummary(for entry: RemoteVideoSearchCacheEntry) {
        let summary = RemoteVideoSearchCacheSummary(
            keyword: entry.keyword,
            totalCount: entry.totalCount,
            fetchedAt: entry.fetchedAt
        )
        guard let data = try? summaryEncoder.encode(summary) else { return }
        let url = FeedCachePaths.remoteSearchCacheSummaryURL(keyword: entry.keyword, fileManager: fileManager)
        try? data.write(to: url, options: .atomic)
    }

    func allVideos(channelID: String) -> [CachedVideo] {
        let baseURL = FeedCachePaths.baseDirectory(fileManager: fileManager)
        let filenames = (try? fileManager.contentsOfDirectory(atPath: baseURL.path)) ?? []
        let urls = filenames
            .filter {
                (($0 == "remote-search.json" || $0.hasPrefix("remote-search-")) && $0.hasSuffix(".json")) && !$0.hasSuffix("-summary.plist")
            }
            .map { baseURL.appendingPathComponent($0) }

        let entries: [RemoteVideoSearchCacheEntry] = urls.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(RemoteVideoSearchCacheEntry.self, from: data)
        }
        return entries.flatMap { $0.videos }.filter { $0.channelID == channelID }
    }
}
