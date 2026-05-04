import Foundation

actor FeedCacheStore {
    typealias ThumbnailFetchOperation = @Sendable (URL) async throws -> (Data, HTTPURLResponse)

    private let fileManager = FileManager.default
    private let encoder = FeedCachePersistenceCoders.makeEncoder()
    private let database = FeedCacheSQLiteDatabase.shared()

    private let baseDirectory: URL
    private let bootstrapFileURL: URL
    private let thumbnailsDirectory: URL
    private var lastConsistencyMaintenanceAt: Date?

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

    func persistBootstrap(progress: CacheProgress, maintenanceItems: [ChannelMaintenanceItem]) {
        try? createDirectories()

        let bootstrap = FeedBootstrapSnapshot(progress: progress, maintenanceItems: maintenanceItems)
        guard let data = try? encoder.encode(bootstrap) else { return }
        try? data.write(to: bootstrapFileURL, options: .atomic)
    }

    func cacheThumbnail(for video: YouTubeVideo) async {
        _ = await cacheThumbnail(videoID: video.id)
    }

    func cacheThumbnail(
        for video: CachedVideo,
        fetch: ThumbnailFetchOperation = FeedCacheStore.fetchThumbnailResponse
    ) async -> String? {
        await cacheThumbnail(videoID: video.id, fetch: fetch)
    }

    func cacheThumbnail(
        videoID: String,
        fetch: ThumbnailFetchOperation = FeedCacheStore.fetchThumbnailResponse
    ) async -> String? {
        guard let filename = YouTubeThumbnailCandidates.cacheFilename(for: videoID) else {
            return nil
        }

        try? createDirectories()
        let localURL = thumbnailsDirectory.appendingPathComponent(filename)

        if fileManager.fileExists(atPath: localURL.path) {
            database.updateThumbnailCache(videoID: videoID, remoteURL: nil, localFilename: filename)
            return filename
        }

        for remoteURL in YouTubeThumbnailCandidates.urls(for: videoID) {
            do {
                let (data, response) = try await fetch(remoteURL)
                guard (200 ..< 300).contains(response.statusCode) else { continue }
                if let contentType = response.value(forHTTPHeaderField: "Content-Type"),
                   !contentType.lowercased().hasPrefix("image/") {
                    continue
                }
                try data.write(to: localURL, options: .atomic)
                database.updateThumbnailCache(videoID: videoID, remoteURL: remoteURL, localFilename: filename)
                return filename
            } catch {
                continue
            }
        }

        return nil
    }

    func performConsistencyMaintenance(activeChannelIDs: [String], force: Bool = false, now: Date = .now) -> CacheConsistencyMaintenanceResult? {
        let maintenanceInterval: TimeInterval = 15 * 60
        if !force, let lastConsistencyMaintenanceAt, now.timeIntervalSince(lastConsistencyMaintenanceAt) < maintenanceInterval {
            return nil
        }

        var snapshot = loadSnapshot()
        let activeChannelIDSet = Set(activeChannelIDs)
        let removedVideos = snapshot.videos.filter { !activeChannelIDSet.contains($0.channelID) }
        let removedVideoCount = removedVideos.count

        snapshot.channels.removeAll { !activeChannelIDSet.contains($0.channelID) }
        snapshot.videos.removeAll { !activeChannelIDSet.contains($0.channelID) }
        snapshot.channels = rebuildChannelStates(afterFiltering: snapshot.channels, videos: snapshot.videos)

        let orphanThumbnailFilenames = orphanThumbnailFilenames(for: snapshot.videos)
        removeThumbnails(named: orphanThumbnailFilenames)

        let removedThumbnailCount = orphanThumbnailFilenames.count
        if removedVideoCount > 0 || removedThumbnailCount > 0 || force {
            snapshot.savedAt = now
            persist(snapshot)
        }

        lastConsistencyMaintenanceAt = now

        guard force, removedVideoCount > 0 || removedThumbnailCount > 0 else {
            return nil
        }

        return CacheConsistencyMaintenanceResult(
            removedVideoCount: removedVideoCount,
            removedThumbnailCount: removedThumbnailCount
        )
    }

    private func rebuildChannelStates(
        afterFiltering channels: [CachedChannelState],
        videos: [CachedVideo]
    ) -> [CachedChannelState] {
        let latestPublishedAtByChannelID = Dictionary(grouping: videos, by: \.channelID)
            .mapValues { $0.compactMap(\.publishedAt).max() }
        let cachedVideoCountByChannelID = Dictionary(grouping: videos, by: \.channelID)
            .mapValues(\.count)

        return channels.map { channel in
            CachedChannelState(
                channelID: channel.channelID,
                channelTitle: channel.channelTitle,
                channelDisplayTitle: channel.channelDisplayTitle,
                lastAttemptAt: channel.lastAttemptAt,
                lastCheckedAt: channel.lastCheckedAt,
                lastSuccessAt: channel.lastSuccessAt,
                latestPublishedAt: latestPublishedAtByChannelID[channel.channelID] ?? nil,
                latestPublishedAtText: CachedChannelState(
                    channelID: channel.channelID,
                    channelTitle: channel.channelTitle,
                    channelDisplayTitle: channel.channelDisplayTitle,
                    lastAttemptAt: channel.lastAttemptAt,
                    lastCheckedAt: channel.lastCheckedAt,
                    lastSuccessAt: channel.lastSuccessAt,
                    latestPublishedAt: latestPublishedAtByChannelID[channel.channelID] ?? nil,
                    cachedVideoCount: cachedVideoCountByChannelID[channel.channelID] ?? 0,
                    lastError: channel.lastError,
                    etag: channel.etag,
                    lastModified: channel.lastModified
                ).latestPublishedAtText,
                cachedVideoCount: cachedVideoCountByChannelID[channel.channelID] ?? 0,
                lastError: channel.lastError,
                etag: channel.etag,
                lastModified: channel.lastModified
            )
        }
    }

    private func orphanThumbnailFilenames(for videos: [CachedVideo]) -> Set<String> {
        let referencedThumbnailFilenames = Set(videos.compactMap(\.thumbnailLocalFilename))
        let existingThumbnailFilenames = Set((try? fileManager.contentsOfDirectory(atPath: thumbnailsDirectory.path)) ?? [])
        return existingThumbnailFilenames.subtracting(referencedThumbnailFilenames)
    }

    private func removeThumbnails(named orphanThumbnailFilenames: Set<String>) {
        for filename in orphanThumbnailFilenames {
            try? fileManager.removeItem(at: thumbnailsDirectory.appendingPathComponent(filename))
        }
    }

    func resetAllStoredData() -> (removedVideoCount: Int, removedThumbnailCount: Int) {
        let snapshot = loadSnapshot()
        let removedVideoCount = snapshot.videos.count
        let removedThumbnailCount = Set(snapshot.videos.compactMap(\.thumbnailLocalFilename)).count

        database.clearFeedCache()
        database.close()
        FeedCacheSQLiteDatabase.resetShared(fileManager: fileManager)
        removeDatabaseFiles()
        removeLegacyRuntimeFiles()
        try? fileManager.removeItem(at: bootstrapFileURL)
        try? fileManager.removeItem(at: thumbnailsDirectory)

        lastConsistencyMaintenanceAt = nil
        return (removedVideoCount, removedThumbnailCount)
    }

    private func persist(_ snapshot: FeedCacheSnapshot) {
        try? createDirectories()
        database.replaceFeedSnapshot(snapshot)
    }

    private func buildSummary(from snapshot: FeedCacheSnapshot) -> FeedCacheSummary {
        let filenames = Set(snapshot.videos.compactMap(\.thumbnailLocalFilename))
        let cachedThumbnailBytes = filenames.reduce(into: Int64(0)) { total, filename in
            let url = thumbnailsDirectory.appendingPathComponent(filename)
            let size = (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
            total += size
        }
        return FeedCacheSummary(
            savedAt: snapshot.savedAt == .distantPast ? nil : snapshot.savedAt,
            cachedChannelCount: snapshot.channels.count,
            cachedVideoCount: snapshot.videos.count,
            cachedThumbnailBytes: cachedThumbnailBytes
        )
    }

    private func createDirectories() throws {
        try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
    }

    nonisolated private static func fetchThumbnailResponse(from remoteURL: URL) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(from: remoteURL)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, httpResponse)
    }

    private func removeDatabaseFiles() {
        let databaseURL = FeedCachePaths.databaseURL(fileManager: fileManager)
        let urls = [
            databaseURL,
            URL(fileURLWithPath: databaseURL.path + "-shm"),
            URL(fileURLWithPath: databaseURL.path + "-wal")
        ]
        urls.forEach { try? fileManager.removeItem(at: $0) }
    }

    private func removeLegacyRuntimeFiles() {
        let baseDirectory = FeedCachePaths.baseDirectory(fileManager: fileManager)
        let legacyURLs = [
            FeedCachePaths.cacheURL(fileManager: fileManager),
            FeedCachePaths.cacheSummaryURL(fileManager: fileManager),
            FeedCachePaths.channelRegistryURL(fileManager: fileManager)
        ]
        legacyURLs.forEach { try? fileManager.removeItem(at: $0) }

        let filenames = (try? fileManager.contentsOfDirectory(atPath: baseDirectory.path)) ?? []
        for filename in filenames where filename.hasPrefix("remote-search") && (filename.hasSuffix(".json") || filename.hasSuffix(".plist")) {
            try? fileManager.removeItem(at: baseDirectory.appendingPathComponent(filename))
        }
    }

    private func sortComparator(_ order: VideoSortOrder) -> (CachedVideo, CachedVideo) -> Bool {
        switch order {
        case .publishedDescending:
            return { lhs, rhs in
                switch (lhs.publishedAt, rhs.publishedAt) {
                case let (left?, right?): return left > right
                case (_?, nil): return true
                case (nil, _?): return false
                default: return lhs.fetchedAt > rhs.fetchedAt
                }
            }
        }
    }

    private func looksLikeShort(_ video: CachedVideo) -> Bool {
        ShortVideoMaskPolicy.shouldMask(
            durationSeconds: video.durationSeconds,
            videoURL: video.videoURL,
            title: video.title
        )
    }

    private func upsert(channel: CachedChannelState, into channels: inout [CachedChannelState]) {
        if let index = channels.firstIndex(where: { $0.channelID == channel.channelID }) {
            channels[index] = channel
        } else {
            channels.append(channel)
        }
    }

    private func matches(_ video: CachedVideo, query: VideoQuery) -> Bool {
        let matchesChannel = query.channelID.map { video.channelID == $0 } ?? true
        let matchesKeyword = query.keyword.map { video.searchableText.contains($0.lowercased()) } ?? true
        let matchesShorts = query.excludeShorts ? !looksLikeShort(video) : true
        return matchesChannel && matchesKeyword && matchesShorts
    }
}
