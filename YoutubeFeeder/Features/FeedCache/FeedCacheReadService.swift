import Foundation

struct FeedCacheRefreshState {
    let snapshot: FeedCacheSnapshot
    let progress: CacheProgress
    let maintenanceItems: [ChannelMaintenanceItem]
    let videos: [CachedVideo]?
}

struct FeedCacheReadService {
    let store: FeedCacheStore
    let remoteSearchCacheStore: RemoteVideoSearchCacheStore

    func loadSnapshot() async -> FeedCacheSnapshot {
        await store.loadSnapshot()
    }

    func loadSummary(snapshot: FeedCacheSnapshot? = nil) async -> FeedCacheSummary? {
        if let snapshot {
            return await store.summary(for: snapshot)
        }
        return await store.loadSummary()
    }

    func loadVideos(query: VideoQuery) async -> [CachedVideo] {
        await store.loadVideos(query: query)
    }

    func countVideos(query: VideoQuery) async -> Int {
        await store.countVideos(query: query)
    }

    func loadChannelBrowseItems(
        channelIDs: [String],
        registeredAtByChannelID: [String: Date?] = [:],
        sortDescriptor: ChannelBrowseSortDescriptor = .default
    ) async -> [ChannelBrowseItem] {
        let items = await store.loadChannelBrowseItems(
            channelIDs: channelIDs,
            registeredAtByChannelID: registeredAtByChannelID
        )
        return FeedOrdering.sortBrowseItems(items, by: sortDescriptor)
    }

    func loadMergedVideosForChannel(_ channelID: String) async -> [CachedVideo] {
        let query = VideoQuery(
            limit: .max,
            channelID: channelID,
            keyword: nil,
            sortOrder: .publishedDescending,
            excludeShorts: true
        )
        let cachedVideos = await loadVideos(query: query)
        let remoteVideos = await remoteSearchCacheStore.allVideos(channelID: channelID)
        let mergedByID = Dictionary((cachedVideos + remoteVideos).map { ($0.id, $0) }, uniquingKeysWith: preferredVideo)
        return mergedByID.values.sorted(by: sortVideos)
    }

    func loadRemoteSearchSnapshot(
        keyword: String,
        limit: Int,
        cacheLifetime: TimeInterval,
        allowExpired: Bool = true,
        now: Date = .now
    ) async -> VideoSearchResult? {
        guard let entry = await remoteSearchCacheStore.load(keyword: keyword) else { return nil }
        let expiresAt = entry.fetchedAt.addingTimeInterval(cacheLifetime)
        guard allowExpired || expiresAt > now else { return nil }
        return VideoSearchResult(
            keyword: entry.keyword,
            videos: Array(entry.videos.prefix(limit)),
            totalCount: entry.totalCount,
            source: allowExpired && expiresAt <= now ? .staleRemoteCache : .remoteCache,
            fetchedAt: entry.fetchedAt,
            expiresAt: expiresAt
        )
    }

    func loadRemoteSearchStatus(
        keyword: String,
        cacheLifetime: TimeInterval,
        now: Date = .now
    ) async -> RemoteSearchCacheStatus {
        await remoteSearchCacheStore.status(keyword: keyword, ttl: cacheLifetime, now: now)
    }

    func searchVideos(keyword: String, limit: Int = 20) async -> VideoSearchResult {
        let normalizedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let query = VideoQuery(
            limit: limit,
            channelID: nil,
            keyword: normalizedKeyword,
            sortOrder: .publishedDescending,
            excludeShorts: true
        )
        let videos = await loadVideos(query: query)
        let totalCount = await countVideos(
            query: VideoQuery(
                limit: .max,
                channelID: nil,
                keyword: normalizedKeyword,
                sortOrder: .publishedDescending,
                excludeShorts: true
            )
        )
        return VideoSearchResult(keyword: normalizedKeyword, videos: videos, totalCount: totalCount, source: .localCache)
    }

    func loadRefreshState(
        channels: [String],
        freshnessInterval: TimeInterval,
        videoQuery: VideoQuery,
        currentChannelID: String?,
        isRunning: Bool,
        lastError: String?,
        includesVideos: Bool
    ) async -> FeedCacheRefreshState {
        let snapshot = await loadSnapshot()
        let progress = buildCacheProgress(
            snapshot: snapshot,
            channels: channels,
            freshnessInterval: freshnessInterval,
            currentChannelID: currentChannelID,
            isRunning: isRunning,
            lastError: lastError
        )
        let maintenanceItems = buildMaintenanceItems(
            snapshot: snapshot,
            channels: channels,
            freshnessInterval: freshnessInterval
        )
        let videos = includesVideos ? await loadVideos(query: videoQuery) : nil
        return FeedCacheRefreshState(
            snapshot: snapshot,
            progress: progress,
            maintenanceItems: maintenanceItems,
            videos: videos
        )
    }

    private func buildCacheProgress(
        snapshot: FeedCacheSnapshot,
        channels: [String],
        freshnessInterval: TimeInterval,
        currentChannelID: String?,
        isRunning: Bool,
        lastError: String?
    ) -> CacheProgress {
        let cachedChannels = snapshot.channels.filter { $0.lastSuccessAt != nil }.count
        let cachedThumbnails = snapshot.videos.filter { $0.thumbnailLocalFilename != nil }.count
        let prioritizedChannels = FeedOrdering.prioritizedChannelIDs(
            channels: channels,
            states: Dictionary(snapshot.channels.map { ($0.channelID, $0) }, uniquingKeysWith: { _, rhs in rhs })
        )
        let currentChannelNumber = currentChannelID
            .flatMap { prioritizedChannels.firstIndex(of: $0) }
            .map { $0 + 1 }
        return CacheProgress(
            totalChannels: channels.count,
            cachedChannels: cachedChannels,
            cachedVideos: snapshot.videos.count,
            cachedThumbnails: cachedThumbnails,
            currentChannelID: currentChannelID,
            currentChannelNumber: currentChannelNumber,
            lastUpdatedAt: snapshot.savedAt == .distantPast ? nil : snapshot.savedAt,
            isRunning: isRunning,
            lastError: lastError
        )
    }

    private func buildMaintenanceItems(
        snapshot: FeedCacheSnapshot,
        channels: [String],
        freshnessInterval: TimeInterval
    ) -> [ChannelMaintenanceItem] {
        let states = Dictionary(snapshot.channels.map { ($0.channelID, $0) }, uniquingKeysWith: { _, rhs in rhs })
        let prioritizedChannels = FeedOrdering.prioritizedChannelIDs(channels: channels, states: states)
        return prioritizedChannels.map { channelID in
            let state = states[channelID]
            return ChannelMaintenanceItem(
                id: channelID,
                channelID: channelID,
                channelTitle: state?.channelTitle,
                lastSuccessAt: state?.lastSuccessAt,
                lastCheckedAt: state?.lastCheckedAt,
                latestPublishedAt: state?.latestPublishedAt,
                cachedVideoCount: state?.cachedVideoCount ?? 0,
                lastError: state?.lastError,
                freshness: FeedOrdering.freshness(
                    lastSuccessAt: state?.lastSuccessAt,
                    freshnessInterval: freshnessInterval
                )
            )
        }
    }

    private func preferredVideo(_ lhs: CachedVideo, _ rhs: CachedVideo) -> CachedVideo {
        switch (lhs.publishedAt, rhs.publishedAt) {
        case let (left?, right?) where left != right:
            return left >= right ? lhs : rhs
        case (_?, nil):
            return lhs
        case (nil, _?):
            return rhs
        default:
            return lhs.fetchedAt >= rhs.fetchedAt ? lhs : rhs
        }
    }

    private func sortVideos(lhs: CachedVideo, rhs: CachedVideo) -> Bool {
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
}
