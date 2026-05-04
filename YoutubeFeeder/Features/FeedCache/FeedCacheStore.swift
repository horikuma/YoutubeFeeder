import Foundation

actor FeedCacheStore {
    typealias ThumbnailFetchOperation = @Sendable (URL) async throws -> (Data, HTTPURLResponse)

    let fileManager = FileManager.default
    let encoder = FeedCachePersistenceCoders.makeEncoder()
    let database = FeedCacheSQLiteDatabase.shared()

    let baseDirectory: URL
    let bootstrapFileURL: URL
    let thumbnailsDirectory: URL
    var lastConsistencyMaintenanceAt: Date?

    init() {
        baseDirectory = FeedCachePaths.baseDirectory(fileManager: fileManager)
        bootstrapFileURL = FeedCachePaths.bootstrapURL(fileManager: fileManager)
        thumbnailsDirectory = FeedCachePaths.thumbnailsDirectory(fileManager: fileManager)
    }

    func loadSnapshot() -> FeedCacheSnapshot {
        try? createDirectories()
        return database.loadFeedSnapshot()
    }

    func loadPlaylistSnapshot() -> FeedCachePlaylistSnapshot {
        try? createDirectories()
        return database.loadPlaylistSnapshot()
    }

    func loadSummary() -> FeedCacheSummary? {
        let snapshot = loadSnapshot()
        guard !snapshot.channels.isEmpty || !snapshot.videos.isEmpty || snapshot.savedAt != .distantPast else {
            return nil
        }
        return buildSummary(from: snapshot)
    }

    func summary(for snapshot: FeedCacheSnapshot) -> FeedCacheSummary {
        buildSummary(from: snapshot)
    }

    func loadVideos(query: VideoQuery) -> [CachedVideo] {
        let snapshot = loadSnapshot()

        return snapshot.videos
            .filter { matches($0, query: query) }
            .sorted(by: sortComparator(query.sortOrder))
            .prefix(query.limit)
            .map { $0 }
    }

    func countVideos(query: VideoQuery) -> Int {
        let snapshot = loadSnapshot()
        return snapshot.videos.filter { matches($0, query: query) }.count
    }

    func totalVideoCount() -> Int {
        loadSnapshot().videos.count
    }

    func recordThumbnailReference(filename: String, accessedAt: Date = .now) {
        database.updateThumbnailLastAccessedAt(filename: filename, accessedAt: accessedAt)
    }

    func clearStoredThumbnailReference(filename: String) {
        database.clearThumbnailReference(filename: filename)
    }

    func removeThumbnailFile(filename: String) {
        removeThumbnails(named: [filename])
    }

    func thumbnailFileSize(filename: String) -> Int64? {
        let url = thumbnailsDirectory.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
    }

    func totalThumbnailBytes() -> Int64 {
        let filenames = Set(loadSnapshot().videos.compactMap(\.thumbnailLocalFilename))
        return filenames.reduce(into: Int64(0)) { total, filename in
            let url = thumbnailsDirectory.appendingPathComponent(filename)
            let size = (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
            total += size
        }
    }

    func loadChannelBrowseItems(channelIDs: [String], registeredAtByChannelID: [String: Date?] = [:]) -> [ChannelBrowseItem] {
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

    func savePlaylistItems(_ items: [PlaylistBrowseItem], channelID: String) {
        database.savePlaylistItems(items, channelID: channelID)
    }

    func savePlaylistVideosPage(_ page: PlaylistBrowseVideosPage) {
        database.savePlaylistVideosPage(page)
    }

    func saveChannelNextPageToken(_ nextPageToken: String?, channelID: String) {
        database.saveChannelNextPageToken(nextPageToken, channelID: channelID)
    }

    func recordFailure(channelID: String, checkedAt: Date, error: String) {
        var snapshot = loadSnapshot()
        var channel = snapshot.channels.first(where: { $0.channelID == channelID }) ?? CachedChannelState(
            channelID: channelID,
            channelTitle: nil,
            lastAttemptAt: nil,
            lastCheckedAt: nil,
            lastSuccessAt: nil,
            latestPublishedAt: nil,
            cachedVideoCount: 0,
            lastError: nil,
            etag: nil,
            lastModified: nil
        )
        channel.lastAttemptAt = checkedAt
        channel.lastCheckedAt = checkedAt
        channel.latestPublishedAtText = CachedChannelState(
            channelID: channel.channelID,
            channelTitle: channel.channelTitle,
            channelDisplayTitle: channel.channelDisplayTitle,
            lastAttemptAt: checkedAt,
            lastCheckedAt: checkedAt,
            lastSuccessAt: channel.lastSuccessAt,
            latestPublishedAt: channel.latestPublishedAt,
            cachedVideoCount: channel.cachedVideoCount,
            lastError: error,
            etag: channel.etag,
            lastModified: channel.lastModified
        ).latestPublishedAtText
        channel.lastError = error
        upsert(channel: channel, into: &snapshot.channels)
        snapshot.savedAt = checkedAt
        persist(snapshot)
    }

    func recordNotModified(channelID: String, metadata: FeedFetchMetadata) {
        var snapshot = loadSnapshot()
        var channel = snapshot.channels.first(where: { $0.channelID == channelID }) ?? CachedChannelState(
            channelID: channelID,
            channelTitle: nil,
            lastAttemptAt: nil,
            lastCheckedAt: nil,
            lastSuccessAt: nil,
            latestPublishedAt: nil,
            cachedVideoCount: 0,
            lastError: nil,
            etag: nil,
            lastModified: nil
        )
        channel.lastAttemptAt = metadata.checkedAt
        channel.lastCheckedAt = metadata.checkedAt
        channel.latestPublishedAtText = CachedChannelState(
            channelID: channel.channelID,
            channelTitle: channel.channelTitle,
            channelDisplayTitle: channel.channelDisplayTitle,
            lastAttemptAt: metadata.checkedAt,
            lastCheckedAt: metadata.checkedAt,
            lastSuccessAt: channel.lastSuccessAt,
            latestPublishedAt: channel.latestPublishedAt,
            cachedVideoCount: channel.cachedVideoCount,
            lastError: nil,
            etag: metadata.validationToken.etag,
            lastModified: metadata.validationToken.lastModified
        ).latestPublishedAtText
        channel.lastError = nil
        channel.etag = metadata.validationToken.etag
        channel.lastModified = metadata.validationToken.lastModified
        upsert(channel: channel, into: &snapshot.channels)
        snapshot.savedAt = metadata.checkedAt
        persist(snapshot)
    }

    func recordSuccess(channelID: String, videos: [YouTubeVideo], metadata: FeedFetchMetadata) async -> [YouTubeVideo] {
        var snapshot = loadSnapshot()
        let fetchedAt = metadata.checkedAt
        let existingChannelVideoCount = snapshot.videos.filter { $0.channelID == channelID }.count
        let existingVideoIDs = Set(snapshot.videos.lazy.map(\.id))
        let uncachedVideos = videos.filter { !existingVideoIDs.contains($0.id) }
        let updatedVideos = updateCachedVideos(
            snapshot.videos,
            with: videos,
            channelID: channelID,
            fetchedAt: fetchedAt
        )
        snapshot.videos = updatedVideos.sorted(by: sortCachedVideosForSnapshot)

        let resolvedChannelTitle = videos.first(where: { !$0.channelTitle.isEmpty })?.channelTitle
        let latestPublishedAt = videos.compactMap(\.publishedAt).max()
        let channelVideoCount = snapshot.videos.filter { $0.channelID == channelID }.count
        AppConsoleLogger.feedRefresh.debug(
            "feed_cache_record_success",
            metadata: [
                "channelID": channelID,
                "fetched_videos": String(videos.count),
                "uncached_videos": String(uncachedVideos.count),
                "existing_channel_videos": String(existingChannelVideoCount),
                "cached_channel_videos_after": String(channelVideoCount),
                "total_cached_videos_after": String(snapshot.videos.count),
                "resolved_channel_title": resolvedChannelTitle ?? "",
                "latest_published_at": latestPublishedAt.map { String(format: "%.3f", $0.timeIntervalSince1970) } ?? "nil",
                "zero_fetch_preserved_existing": videos.isEmpty && channelVideoCount > 0 ? "true" : "false"
            ]
        )

        var channel = snapshot.channels.first(where: { $0.channelID == channelID }) ?? CachedChannelState(
            channelID: channelID,
            channelTitle: nil,
            lastAttemptAt: nil,
            lastCheckedAt: nil,
            lastSuccessAt: nil,
            latestPublishedAt: nil,
            cachedVideoCount: 0,
            lastError: nil,
            etag: nil,
            lastModified: nil
        )
        channel.channelTitle = resolvedChannelTitle ?? channel.channelTitle
        channel.channelDisplayTitle = resolvedChannelTitle ?? channel.channelDisplayTitle
        channel.lastAttemptAt = fetchedAt
        channel.lastCheckedAt = fetchedAt
        channel.lastSuccessAt = fetchedAt
        channel.latestPublishedAt = latestPublishedAt ?? channel.latestPublishedAt
        channel.latestPublishedAtText = CachedChannelState(
            channelID: channel.channelID,
            channelTitle: channel.channelTitle,
            channelDisplayTitle: channel.channelDisplayTitle,
            lastAttemptAt: fetchedAt,
            lastCheckedAt: fetchedAt,
            lastSuccessAt: fetchedAt,
            latestPublishedAt: latestPublishedAt ?? channel.latestPublishedAt,
            cachedVideoCount: channelVideoCount,
            lastError: nil,
            etag: metadata.validationToken.etag,
            lastModified: metadata.validationToken.lastModified
        ).latestPublishedAtText
        channel.cachedVideoCount = channelVideoCount
        channel.lastError = nil
        channel.etag = metadata.validationToken.etag
        channel.lastModified = metadata.validationToken.lastModified
        upsert(channel: channel, into: &snapshot.channels)

        snapshot.savedAt = fetchedAt
        persist(snapshot)
        return uncachedVideos
    }

    private func updateCachedVideos(
        _ existingVideos: [CachedVideo],
        with fetchedVideos: [YouTubeVideo],
        channelID: String,
        fetchedAt: Date
    ) -> [CachedVideo] {
        var cachedVideosByID = Dictionary(existingVideos.map { ($0.id, $0) }, uniquingKeysWith: { _, rhs in rhs })
        for video in fetchedVideos {
            cachedVideosByID[video.id] = buildCachedVideo(
                from: video,
                channelID: channelID,
                fetchedAt: fetchedAt,
                existing: cachedVideosByID[video.id]
            )
        }
        return Array(cachedVideosByID.values)
    }

    private func buildCachedVideo(
        from video: YouTubeVideo,
        channelID: String,
        fetchedAt: Date,
        existing: CachedVideo?
    ) -> CachedVideo {
        let channelTitle = video.channelTitle.isEmpty ? (existing?.channelTitle ?? "") : video.channelTitle
        return CachedVideo(
            id: video.id,
            channelID: channelID,
            channelTitle: channelTitle,
            channelDisplayTitle: channelTitle.isEmpty ? channelID : channelTitle,
            title: video.title,
            publishedAt: video.publishedAt,
            videoURL: video.videoURL,
            thumbnailRemoteURL: existing?.thumbnailRemoteURL ?? video.thumbnailURL,
            thumbnailLocalFilename: existing?.thumbnailLocalFilename,
            thumbnailLastAccessedAt: existing?.thumbnailLastAccessedAt,
            fetchedAt: fetchedAt,
            searchableText: [video.title, channelTitle, video.id].joined(separator: "\n").lowercased(),
            durationSeconds: video.durationSeconds ?? existing?.durationSeconds,
            viewCount: video.viewCount ?? existing?.viewCount
        )
    }

    private func sortCachedVideosForSnapshot(lhs: CachedVideo, rhs: CachedVideo) -> Bool {
        switch (lhs.publishedAt, rhs.publishedAt) {
        case let (left?, right?):
            return left > right
        case (_?, nil):
            return true
        default:
            return lhs.fetchedAt > rhs.fetchedAt
        }
    }
}
