import Foundation

actor FeedCacheStore {
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

    private let baseDirectory: URL
    private let cacheFileURL: URL
    private let bootstrapFileURL: URL
    private let thumbnailsDirectory: URL
    private var lastConsistencyMaintenanceAt: Date?

    init() {
        baseDirectory = FeedCachePaths.baseDirectory(fileManager: fileManager)
        cacheFileURL = FeedCachePaths.cacheURL(fileManager: fileManager)
        bootstrapFileURL = FeedCachePaths.bootstrapURL(fileManager: fileManager)
        thumbnailsDirectory = FeedCachePaths.thumbnailsDirectory(fileManager: fileManager)
    }

    func loadSnapshot() -> FeedCacheSnapshot {
        try? createDirectories()

        guard let data = try? Data(contentsOf: cacheFileURL),
              let snapshot = try? decoder.decode(FeedCacheSnapshot.self, from: data) else {
            return .empty
        }

        return snapshot
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

        snapshot.videos.removeAll { $0.channelID == channelID }
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
                searchableText: [video.title, channelTitle, video.id].joined(separator: "\n").lowercased()
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
                searchableText: existing.searchableText
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
