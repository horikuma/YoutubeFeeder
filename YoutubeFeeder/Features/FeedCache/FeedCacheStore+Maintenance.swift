import Foundation

extension FeedCacheStore {
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

    func rebuildChannelStates(
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

    func orphanThumbnailFilenames(for videos: [CachedVideo]) -> Set<String> {
        let referencedThumbnailFilenames = Set(videos.compactMap(\.thumbnailLocalFilename))
        let existingThumbnailFilenames = Set((try? fileManager.contentsOfDirectory(atPath: thumbnailsDirectory.path)) ?? [])
        return existingThumbnailFilenames.subtracting(referencedThumbnailFilenames)
    }

    func removeThumbnails(named orphanThumbnailFilenames: Set<String>) {
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

    func persist(_ snapshot: FeedCacheSnapshot) {
        try? createDirectories()
        database.replaceFeedSnapshot(snapshot)
    }

    func buildSummary(from snapshot: FeedCacheSnapshot) -> FeedCacheSummary {
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

    func createDirectories() throws {
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

    func removeDatabaseFiles() {
        let databaseURL = FeedCachePaths.databaseURL(fileManager: fileManager)
        let urls = [
            databaseURL,
            URL(fileURLWithPath: databaseURL.path + "-shm"),
            URL(fileURLWithPath: databaseURL.path + "-wal")
        ]
        urls.forEach { try? fileManager.removeItem(at: $0) }
    }

    func removeLegacyRuntimeFiles() {
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

    func sortComparator(_ order: VideoSortOrder) -> (CachedVideo, CachedVideo) -> Bool {
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

    func looksLikeShort(_ video: CachedVideo) -> Bool {
        ShortVideoMaskPolicy.shouldMask(
            durationSeconds: video.durationSeconds,
            videoURL: video.videoURL,
            title: video.title
        )
    }

    func upsert(channel: CachedChannelState, into channels: inout [CachedChannelState]) {
        if let index = channels.firstIndex(where: { $0.channelID == channel.channelID }) {
            channels[index] = channel
        } else {
            channels.append(channel)
        }
    }

    func matches(_ video: CachedVideo, query: VideoQuery) -> Bool {
        let matchesChannel = query.channelID.map { video.channelID == $0 } ?? true
        let matchesKeyword = query.keyword.map { video.searchableText.contains($0.lowercased()) } ?? true
        let matchesShorts = query.excludeShorts ? !looksLikeShort(video) : true
        return matchesChannel && matchesKeyword && matchesShorts
    }
}
