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
        let successContext = FeedCacheStoreWriterSuccessContext(
            channelID: channelID,
            fetchedAt: fetchedAt,
            fetchedVideos: videos.count,
            uncachedVideos: uncachedVideos.count,
            existingChannelVideos: existingChannelVideoCount,
            cachedChannelVideosAfter: channelVideoCount,
            totalCachedVideosAfter: snapshot.videos.count,
            resolvedChannelTitle: resolvedChannelTitle,
            latestPublishedAt: latestPublishedAt,
            cachedVideoCount: channelVideoCount,
            zeroFetchPreservedExisting: videos.isEmpty && channelVideoCount > 0,
            validationToken: metadata.validationToken
        )
        AppConsoleLogger.feedRefresh.debug(
            "feed_cache_record_success",
            metadata: successMetadata(context: successContext)
        )
        updateChannelAfterSuccess(
            context: successContext,
            snapshot: &snapshot
        )

        snapshot.savedAt = fetchedAt
        persist(snapshot)
        return uncachedVideos
    }

    private func updateChannelAfterSuccess(
        context: FeedCacheStoreWriterSuccessContext,
        snapshot: inout FeedCacheSnapshot
    ) {
        var channel = channelState(for: context.channelID, in: snapshot.channels)
        channel.channelTitle = context.resolvedChannelTitle ?? channel.channelTitle
        channel.channelDisplayTitle = context.resolvedChannelTitle ?? channel.channelDisplayTitle
        channel.lastAttemptAt = context.fetchedAt
        channel.lastCheckedAt = context.fetchedAt
        channel.lastSuccessAt = context.fetchedAt
        channel.latestPublishedAt = context.latestPublishedAt ?? channel.latestPublishedAt
        channel.latestPublishedAtText = CachedChannelState(
            channelID: channel.channelID,
            channelTitle: channel.channelTitle,
            channelDisplayTitle: channel.channelDisplayTitle,
            lastAttemptAt: context.fetchedAt,
            lastCheckedAt: context.fetchedAt,
            lastSuccessAt: context.fetchedAt,
            latestPublishedAt: context.latestPublishedAt ?? channel.latestPublishedAt,
            cachedVideoCount: context.cachedVideoCount,
            lastError: nil,
            etag: context.validationToken.etag,
            lastModified: context.validationToken.lastModified
        ).latestPublishedAtText
        channel.cachedVideoCount = context.cachedVideoCount
        channel.lastError = nil
        channel.etag = context.validationToken.etag
        channel.lastModified = context.validationToken.lastModified
        upsert(channel: channel, into: &snapshot.channels)
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

private struct FeedCacheStoreWriterSuccessContext {
    let channelID: String
    let fetchedAt: Date
    let fetchedVideos: Int
    let uncachedVideos: Int
    let existingChannelVideos: Int
    let cachedChannelVideosAfter: Int
    let totalCachedVideosAfter: Int
    let resolvedChannelTitle: String?
    let latestPublishedAt: Date?
    let cachedVideoCount: Int
    let zeroFetchPreservedExisting: Bool
    let validationToken: FeedValidationToken
}

private func successMetadata(
    context: FeedCacheStoreWriterSuccessContext
) -> [String: String] {
    [
        "channelID": context.channelID,
        "fetched_videos": String(context.fetchedVideos),
        "uncached_videos": String(context.uncachedVideos),
        "existing_channel_videos": String(context.existingChannelVideos),
        "cached_channel_videos_after": String(context.cachedChannelVideosAfter),
        "total_cached_videos_after": String(context.totalCachedVideosAfter),
        "resolved_channel_title": context.resolvedChannelTitle ?? "",
        "latest_published_at": context.latestPublishedAt.map { String(format: "%.3f", $0.timeIntervalSince1970) } ?? "nil",
        "zero_fetch_preserved_existing": context.zeroFetchPreservedExisting ? "true" : "false"
    ]
}
