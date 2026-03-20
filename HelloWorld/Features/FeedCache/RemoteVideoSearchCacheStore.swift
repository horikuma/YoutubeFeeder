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

    func clearAll() -> Int {
        let baseURL = FeedCachePaths.baseDirectory(fileManager: fileManager)
        let filenames = (try? fileManager.contentsOfDirectory(atPath: baseURL.path)) ?? []
        let targets = filenames.filter {
            ($0 == "remote-search.json" || $0.hasPrefix("remote-search-")) && $0.hasSuffix(".json")
        }
        for filename in targets {
            try? fileManager.removeItem(at: baseURL.appendingPathComponent(filename))
        }
        return targets.count
    }

    func status(keyword: String, ttl: TimeInterval, now: Date = .now) -> RemoteSearchCacheStatus {
        let startedAt = Date()
        let keywordPreview = AppConsoleLogger.sanitizedKeyword(keyword)
        let fileURL = FeedCachePaths.remoteSearchCacheURL(keyword: keyword, fileManager: fileManager)
        AppConsoleLogger.appLifecycle.debug(
            "search_cache_status_store_start",
            metadata: [
                "keyword": keywordPreview,
                "filename": fileURL.lastPathComponent,
            ]
        )

        let fileExists = fileManager.fileExists(atPath: fileURL.path)
        let fileCheckedAt = Date()
        guard fileExists else {
            AppConsoleLogger.appLifecycle.notice(
                "search_cache_status_store_empty",
                metadata: [
                    "keyword": keywordPreview,
                    "exists": "false",
                    "file_check_ms": AppConsoleLogger.elapsedMilliseconds(from: startedAt, to: fileCheckedAt),
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                ]
            )
            return .empty(keyword: keyword)
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            AppConsoleLogger.appLifecycle.error(
                "search_cache_status_store_read_failed",
                message: AppConsoleLogger.errorSummary(error),
                metadata: [
                    "keyword": keywordPreview,
                    "exists": "true",
                    "file_check_ms": AppConsoleLogger.elapsedMilliseconds(from: startedAt, to: fileCheckedAt),
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                ]
            )
            return .empty(keyword: keyword)
        }
        let dataLoadedAt = Date()

        let entry: RemoteVideoSearchCacheEntry
        do {
            entry = try decoder.decode(RemoteVideoSearchCacheEntry.self, from: data)
        } catch {
            AppConsoleLogger.appLifecycle.error(
                "search_cache_status_store_decode_failed",
                message: AppConsoleLogger.errorSummary(error),
                metadata: [
                    "keyword": keywordPreview,
                    "bytes": String(data.count),
                    "file_check_ms": AppConsoleLogger.elapsedMilliseconds(from: startedAt, to: fileCheckedAt),
                    "read_ms": AppConsoleLogger.elapsedMilliseconds(from: fileCheckedAt, to: dataLoadedAt),
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                ]
            )
            return .empty(keyword: keyword)
        }
        let decodedAt = Date()

        let expiresAt = entry.fetchedAt.addingTimeInterval(ttl)
        let status = RemoteSearchCacheStatus(
            keyword: keyword,
            isFresh: expiresAt > now,
            totalCount: entry.totalCount,
            fetchedAt: entry.fetchedAt,
            expiresAt: expiresAt,
            exists: true
        )
        let completedAt = Date()
        AppConsoleLogger.appLifecycle.notice(
            "search_cache_status_store_complete",
            metadata: [
                "keyword": keywordPreview,
                "bytes": String(data.count),
                "videos": String(entry.videos.count),
                "exists": "true",
                "is_fresh": status.isFresh ? "true" : "false",
                "file_check_ms": AppConsoleLogger.elapsedMilliseconds(from: startedAt, to: fileCheckedAt),
                "read_ms": AppConsoleLogger.elapsedMilliseconds(from: fileCheckedAt, to: dataLoadedAt),
                "decode_ms": AppConsoleLogger.elapsedMilliseconds(from: dataLoadedAt, to: decodedAt),
                "ttl_ms": AppConsoleLogger.elapsedMilliseconds(from: decodedAt, to: completedAt),
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(from: startedAt, to: completedAt),
            ]
        )
        return status
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
