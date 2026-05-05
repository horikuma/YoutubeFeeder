import Foundation

struct FeedCacheStoreReader {
    let fileManager: FileManager
    let database: FeedCacheSQLiteDatabase
    let thumbnailsDirectory: URL

    func loadSnapshot(createDirectories: () throws -> Void) -> FeedCacheSnapshot {
        try? createDirectories()
        return database.loadFeedSnapshot()
    }

    func loadPlaylistSnapshot(createDirectories: () throws -> Void) -> FeedCachePlaylistSnapshot {
        try? createDirectories()
        return database.loadPlaylistSnapshot()
    }

    func loadSummary(loadSnapshot: () -> FeedCacheSnapshot) -> FeedCacheSummary? {
        let snapshot = loadSnapshot()
        guard !snapshot.channels.isEmpty || !snapshot.videos.isEmpty || snapshot.savedAt != .distantPast else {
            return nil
        }
        return buildSummary(from: snapshot)
    }

    func summary(for snapshot: FeedCacheSnapshot) -> FeedCacheSummary {
        buildSummary(from: snapshot)
    }

    func loadVideos(
        query: VideoQuery,
        loadSnapshot: () -> FeedCacheSnapshot,
        matches: (CachedVideo, VideoQuery) -> Bool,
        sortComparator: (VideoSortOrder) -> (CachedVideo, CachedVideo) -> Bool
    ) -> [CachedVideo] {
        let snapshot = loadSnapshot()
        return snapshot.videos
            .filter { matches($0, query) }
            .sorted(by: sortComparator(query.sortOrder))
            .prefix(query.limit)
            .map { $0 }
    }

    func countVideos(query: VideoQuery, loadSnapshot: () -> FeedCacheSnapshot, matches: (CachedVideo, VideoQuery) -> Bool) -> Int {
        let snapshot = loadSnapshot()
        return snapshot.videos.filter { matches($0, query) }.count
    }

    func totalVideoCount(loadSnapshot: () -> FeedCacheSnapshot) -> Int {
        loadSnapshot().videos.count
    }

    func thumbnailFileSize(filename: String) -> Int64? {
        let url = thumbnailsDirectory.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return thumbnailBytes(at: url)
    }

    func totalThumbnailBytes(loadSnapshot: () -> FeedCacheSnapshot) -> Int64 {
        let filenames = Set(loadSnapshot().videos.compactMap(\.thumbnailLocalFilename))
        return cachedThumbnailBytes(for: filenames)
    }

    func loadChannelBrowseItems(
        channelIDs: [String],
        registeredAtByChannelID: [String: Date?] = [:],
        loadSnapshot: () -> FeedCacheSnapshot,
        looksLikeShort: (CachedVideo) -> Bool,
        sortComparator: (VideoSortOrder) -> (CachedVideo, CachedVideo) -> Bool
    ) -> [ChannelBrowseItem] {
        let snapshot = loadSnapshot()
        let groupedVideos = Dictionary(grouping: snapshot.videos.filter { !looksLikeShort($0) }, by: \.channelID)
        let states = Dictionary(snapshot.channels.map { ($0.channelID, $0) }, uniquingKeysWith: { _, rhs in rhs })

        return channelIDs.map { channelID in
            let latestVideo = groupedVideos[channelID]?.sorted(by: sortComparator(.publishedDescending)).first
            let state = states[channelID]
            return ChannelBrowseItem(
                id: channelID,
                channelID: channelID,
                channelTitle: state?.channelTitle ?? latestVideo?.channelTitle ?? channelID,
                channelDisplayTitle: state?.channelDisplayTitle ?? latestVideo?.channelDisplayTitle ?? channelID,
                latestPublishedAt: state?.latestPublishedAt ?? latestVideo?.publishedAt,
                latestPublishedAtText: state?.latestPublishedAtText ?? latestVideo?.publishedAtText ?? "投稿日なし",
                registeredAt: registeredAtByChannelID[channelID] ?? nil,
                latestVideo: latestVideo,
                cachedVideoCount: state?.cachedVideoCount ?? groupedVideos[channelID]?.count ?? 0
            )
        }
    }

    func buildSummary(from snapshot: FeedCacheSnapshot) -> FeedCacheSummary {
        FeedCacheSummary(
            savedAt: snapshot.savedAt == .distantPast ? nil : snapshot.savedAt,
            cachedChannelCount: snapshot.channels.count,
            cachedVideoCount: snapshot.videos.count,
            cachedThumbnailBytes: cachedThumbnailBytes(for: Set(snapshot.videos.compactMap(\.thumbnailLocalFilename)))
        )
    }

    private func cachedThumbnailBytes(for filenames: Set<String>) -> Int64 {
        filenames.reduce(into: Int64(0)) { total, filename in
            guard let size = thumbnailFileSize(filename: filename) else { return }
            total += size
        }
    }

    private func thumbnailBytes(at url: URL) -> Int64 {
        (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
    }
}
