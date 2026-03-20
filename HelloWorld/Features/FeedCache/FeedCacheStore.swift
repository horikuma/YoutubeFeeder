import Foundation

actor FeedCacheStore {
    private let fileManager = FileManager.default
    private let encoder = FeedCachePersistenceCoders.makeEncoder()
    private let decoder = FeedCachePersistenceCoders.makeDecoder()
    private let summaryEncoder = FeedCachePersistenceCoders.makeEncoder()
    private let summaryDecoder = FeedCachePersistenceCoders.makeDecoder()

    private let baseDirectory: URL
    private let cacheFileURL: URL
    private let summaryFileURL: URL
    private let bootstrapFileURL: URL
    private let thumbnailsDirectory: URL
    private var lastConsistencyMaintenanceAt: Date?

    init() {
        baseDirectory = FeedCachePaths.baseDirectory(fileManager: fileManager)
        cacheFileURL = FeedCachePaths.cacheURL(fileManager: fileManager)
        summaryFileURL = FeedCachePaths.cacheSummaryURL(fileManager: fileManager)
        bootstrapFileURL = FeedCachePaths.bootstrapURL(fileManager: fileManager)
        thumbnailsDirectory = FeedCachePaths.thumbnailsDirectory(fileManager: fileManager)
    }

    func loadSnapshot() -> FeedCacheSnapshot {
        let startedAt = Date()
        AppConsoleLogger.appLifecycle.debug(
            "feed_snapshot_store_start",
            metadata: [
                "filename": cacheFileURL.lastPathComponent,
            ]
        )

        try? createDirectories()
        let directoriesReadyAt = Date()

        let fileExists = fileManager.fileExists(atPath: cacheFileURL.path)
        let fileCheckedAt = Date()
        guard fileExists else {
            AppConsoleLogger.appLifecycle.notice(
                "feed_snapshot_store_empty",
                metadata: [
                    "directories_ms": AppConsoleLogger.elapsedMilliseconds(from: startedAt, to: directoriesReadyAt),
                    "file_check_ms": AppConsoleLogger.elapsedMilliseconds(from: directoriesReadyAt, to: fileCheckedAt),
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                ]
            )
            return .empty
        }

        let data: Data
        do {
            data = try Data(contentsOf: cacheFileURL)
        } catch {
            AppConsoleLogger.appLifecycle.error(
                "feed_snapshot_store_read_failed",
                message: AppConsoleLogger.errorSummary(error),
                metadata: [
                    "directories_ms": AppConsoleLogger.elapsedMilliseconds(from: startedAt, to: directoriesReadyAt),
                    "file_check_ms": AppConsoleLogger.elapsedMilliseconds(from: directoriesReadyAt, to: fileCheckedAt),
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                ]
            )
            return .empty
        }
        let dataLoadedAt = Date()

        let snapshot: FeedCacheSnapshot
        do {
            snapshot = try decoder.decode(FeedCacheSnapshot.self, from: data)
        } catch {
            AppConsoleLogger.appLifecycle.error(
                "feed_snapshot_store_decode_failed",
                message: AppConsoleLogger.errorSummary(error),
                metadata: [
                    "bytes": String(data.count),
                    "directories_ms": AppConsoleLogger.elapsedMilliseconds(from: startedAt, to: directoriesReadyAt),
                    "file_check_ms": AppConsoleLogger.elapsedMilliseconds(from: directoriesReadyAt, to: fileCheckedAt),
                    "read_ms": AppConsoleLogger.elapsedMilliseconds(from: fileCheckedAt, to: dataLoadedAt),
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                ]
            )
            return .empty
        }
        let decodedAt = Date()

        AppConsoleLogger.appLifecycle.notice(
            "feed_snapshot_store_complete",
            metadata: [
                "bytes": String(data.count),
                "videos": String(snapshot.videos.count),
                "channels": String(snapshot.channels.count),
                "directories_ms": AppConsoleLogger.elapsedMilliseconds(from: startedAt, to: directoriesReadyAt),
                "file_check_ms": AppConsoleLogger.elapsedMilliseconds(from: directoriesReadyAt, to: fileCheckedAt),
                "read_ms": AppConsoleLogger.elapsedMilliseconds(from: fileCheckedAt, to: dataLoadedAt),
                "decode_ms": AppConsoleLogger.elapsedMilliseconds(from: dataLoadedAt, to: decodedAt),
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(from: startedAt, to: decodedAt),
            ]
        )

        persistSummary(snapshot)

        return snapshot
    }

    func loadSummary() -> FeedCacheSummary? {
        try? createDirectories()

        guard let data = try? Data(contentsOf: summaryFileURL),
              let summary = try? summaryDecoder.decode(FeedCacheSummary.self, from: data) else {
            return nil
        }

        return summary
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
        let states = Dictionary(uniqueKeysWithValues: snapshot.channels.map { ($0.channelID, $0) })

        return channelIDs.map { channelID in
            let latestVideo = groupedVideos[channelID]?.sorted(by: sortComparator(.publishedDescending)).first
            let state = states[channelID]
            return ChannelBrowseItem(
                id: channelID,
                channelID: channelID,
                channelTitle: state?.channelTitle ?? latestVideo?.channelTitle ?? channelID,
                latestPublishedAt: state?.latestPublishedAt ?? latestVideo?.publishedAt,
                registeredAt: registeredAtByChannelID[channelID] ?? nil,
                latestVideo: latestVideo,
                cachedVideoCount: state?.cachedVideoCount ?? groupedVideos[channelID]?.count ?? 0
            )
        }
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
        let existingVideoIDs = Set(snapshot.videos.lazy.map(\.id))
        let uncachedVideos = videos.filter { !existingVideoIDs.contains($0.id) }
        var cachedVideosByID = Dictionary(uniqueKeysWithValues: snapshot.videos.map { ($0.id, $0) })

        for video in videos {
            let channelTitle = video.channelTitle.isEmpty ? (cachedVideosByID[video.id]?.channelTitle ?? "") : video.channelTitle
            cachedVideosByID[video.id] = CachedVideo(
                id: video.id,
                channelID: channelID,
                channelTitle: channelTitle,
                title: video.title,
                publishedAt: video.publishedAt,
                videoURL: video.videoURL,
                thumbnailRemoteURL: video.thumbnailURL,
                thumbnailLocalFilename: cachedVideosByID[video.id]?.thumbnailLocalFilename,
                fetchedAt: fetchedAt,
                searchableText: [video.title, channelTitle, video.id].joined(separator: "\n").lowercased(),
                durationSeconds: video.durationSeconds ?? cachedVideosByID[video.id]?.durationSeconds,
                viewCount: video.viewCount ?? cachedVideosByID[video.id]?.viewCount
            )
        }

        snapshot.videos = cachedVideosByID.values.sorted {
            switch ($0.publishedAt, $1.publishedAt) {
            case let (left?, right?): return left > right
            case (_?, nil): return true
            default: return $0.fetchedAt > $1.fetchedAt
            }
        }

        let resolvedChannelTitle = videos.first(where: { !$0.channelTitle.isEmpty })?.channelTitle
        let latestPublishedAt = videos.compactMap(\.publishedAt).max()
        let channelVideoCount = snapshot.videos.filter { $0.channelID == channelID }.count

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
        channel.lastAttemptAt = fetchedAt
        channel.lastCheckedAt = fetchedAt
        channel.lastSuccessAt = fetchedAt
        channel.latestPublishedAt = latestPublishedAt ?? channel.latestPublishedAt
        channel.cachedVideoCount = channelVideoCount
        channel.lastError = nil
        channel.etag = metadata.validationToken.etag
        channel.lastModified = metadata.validationToken.lastModified
        upsert(channel: channel, into: &snapshot.channels)

        snapshot.savedAt = fetchedAt
        persist(snapshot)
        return uncachedVideos
    }

    func persistBootstrap(progress: CacheProgress, maintenanceItems: [ChannelMaintenanceItem]) {
        try? createDirectories()

        let bootstrap = FeedBootstrapSnapshot(progress: progress, maintenanceItems: maintenanceItems)
        guard let data = try? encoder.encode(bootstrap) else { return }
        try? data.write(to: bootstrapFileURL, options: .atomic)
    }

    func cacheThumbnail(for video: YouTubeVideo) async {
        guard let localThumbnailFilename = await cacheThumbnailIfNeeded(from: video.thumbnailURL, videoID: video.id) else {
            return
        }

        var snapshot = loadSnapshot()
        guard let index = snapshot.videos.firstIndex(where: { $0.id == video.id }) else {
            return
        }

        if snapshot.videos[index].thumbnailLocalFilename != localThumbnailFilename {
            let existing = snapshot.videos[index]
            snapshot.videos[index] = CachedVideo(
                id: existing.id,
                channelID: existing.channelID,
                channelTitle: existing.channelTitle,
                title: existing.title,
                publishedAt: existing.publishedAt,
                videoURL: existing.videoURL,
                thumbnailRemoteURL: existing.thumbnailRemoteURL,
                thumbnailLocalFilename: localThumbnailFilename,
                fetchedAt: existing.fetchedAt,
                searchableText: existing.searchableText,
                durationSeconds: existing.durationSeconds,
                viewCount: existing.viewCount
            )
            snapshot.savedAt = .now
            persist(snapshot)
        }
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

        let latestPublishedAtByChannelID = Dictionary(
            grouping: snapshot.videos,
            by: \.channelID
        ).mapValues { videos in
            videos.compactMap(\.publishedAt).max()
        }
        let cachedVideoCountByChannelID = Dictionary(
            grouping: snapshot.videos,
            by: \.channelID
        ).mapValues(\.count)

        snapshot.channels = snapshot.channels.map { channel in
            CachedChannelState(
                channelID: channel.channelID,
                channelTitle: channel.channelTitle,
                lastAttemptAt: channel.lastAttemptAt,
                lastCheckedAt: channel.lastCheckedAt,
                lastSuccessAt: channel.lastSuccessAt,
                latestPublishedAt: latestPublishedAtByChannelID[channel.channelID] ?? nil,
                cachedVideoCount: cachedVideoCountByChannelID[channel.channelID] ?? 0,
                lastError: channel.lastError,
                etag: channel.etag,
                lastModified: channel.lastModified
            )
        }

        let referencedThumbnailFilenames = Set(snapshot.videos.compactMap(\.thumbnailLocalFilename))
        let existingThumbnailFilenames = Set((try? fileManager.contentsOfDirectory(atPath: thumbnailsDirectory.path)) ?? [])
        let orphanThumbnailFilenames = existingThumbnailFilenames.subtracting(referencedThumbnailFilenames)
        for filename in orphanThumbnailFilenames {
            try? fileManager.removeItem(at: thumbnailsDirectory.appendingPathComponent(filename))
        }

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

    func resetAllStoredData() -> (removedVideoCount: Int, removedThumbnailCount: Int) {
        let snapshot = loadSnapshot()
        let removedVideoCount = snapshot.videos.count
        let removedThumbnailCount = Set(snapshot.videos.compactMap(\.thumbnailLocalFilename)).count

        try? fileManager.removeItem(at: cacheFileURL)
        try? fileManager.removeItem(at: summaryFileURL)
        try? fileManager.removeItem(at: bootstrapFileURL)
        try? fileManager.removeItem(at: thumbnailsDirectory)

        lastConsistencyMaintenanceAt = nil
        return (removedVideoCount, removedThumbnailCount)
    }

    private func cacheThumbnailIfNeeded(from remoteURL: URL?, videoID: String) async -> String? {
        guard let remoteURL else { return nil }

        try? createDirectories()

        let ext = remoteURL.pathExtension.isEmpty ? "jpg" : remoteURL.pathExtension
        let filename = "\(videoID).\(ext)"
        let localURL = thumbnailsDirectory.appendingPathComponent(filename)

        if fileManager.fileExists(atPath: localURL.path) {
            return filename
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: remoteURL)
            try data.write(to: localURL, options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    private func persist(_ snapshot: FeedCacheSnapshot) {
        try? createDirectories()
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: cacheFileURL, options: .atomic)
        persistSummary(snapshot)
    }

    private func persistSummary(_ snapshot: FeedCacheSnapshot) {
        let summary = buildSummary(from: snapshot)
        guard let data = try? summaryEncoder.encode(summary) else { return }
        try? data.write(to: summaryFileURL, options: .atomic)
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
        if let videoURL = video.videoURL?.absoluteString.lowercased(), videoURL.contains("/shorts/") {
            return true
        }

        let title = video.title.lowercased()
        return title.contains("#shorts") || title.hasPrefix("shorts")
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
