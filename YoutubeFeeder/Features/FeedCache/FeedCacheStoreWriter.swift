import Foundation

struct FeedCacheStoreWriter {
    let database: FeedCacheSQLiteDatabase

    func recordThumbnailReference(filename: String, accessedAt: Date = .now) {
        database.updateThumbnailLastAccessedAt(filename: filename, accessedAt: accessedAt)
    }

    func clearStoredThumbnailReference(filename: String) {
        database.clearThumbnailReference(filename: filename)
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

    func recordFailure(
        channelID: String,
        checkedAt: Date,
        error: String,
        loadSnapshot: () -> FeedCacheSnapshot,
        persist: (FeedCacheSnapshot) -> Void
    ) {
        var snapshot = loadSnapshot()
        var channel = channelState(for: channelID, in: snapshot.channels)
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

    func recordNotModified(
        channelID: String,
        metadata: FeedFetchMetadata,
        loadSnapshot: () -> FeedCacheSnapshot,
        persist: (FeedCacheSnapshot) -> Void
    ) {
        var snapshot = loadSnapshot()
        var channel = channelState(for: channelID, in: snapshot.channels)
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

    func recordSuccess(
        channelID: String,
        videos: [YouTubeVideo],
        metadata: FeedFetchMetadata,
        loadSnapshot: () -> FeedCacheSnapshot,
        persist: (FeedCacheSnapshot) -> Void
    ) async -> [YouTubeVideo] {
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

        var channel = channelState(for: channelID, in: snapshot.channels)
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

    private func channelState(
        for channelID: String,
        in channels: [CachedChannelState]
    ) -> CachedChannelState {
        channels.first(where: { $0.channelID == channelID }) ?? CachedChannelState(
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
    }

    private func upsert(channel: CachedChannelState, into channels: inout [CachedChannelState]) {
        if let index = channels.firstIndex(where: { $0.channelID == channel.channelID }) {
            channels[index] = channel
        } else {
            channels.append(channel)
        }
    }
}
