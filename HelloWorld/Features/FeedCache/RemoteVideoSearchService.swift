import Foundation

struct RemoteVideoSearchService {
    let searchService: YouTubeSearchService
    let cacheStore: RemoteVideoSearchCacheStore
    let cacheLifetime: TimeInterval

    var isConfigured: Bool {
        searchService.isConfigured
    }

    func loadSnapshot(keyword: String, limit: Int, allowExpired: Bool = true) async -> VideoSearchResult? {
        guard let entry = await cacheStore.load(keyword: keyword) else { return nil }
        let expiresAt = entry.fetchedAt.addingTimeInterval(cacheLifetime)
        guard allowExpired || expiresAt > .now else { return nil }
        return VideoSearchResult(
            keyword: entry.keyword,
            videos: Array(entry.videos.prefix(limit)),
            totalCount: entry.totalCount,
            source: allowExpired && expiresAt <= .now ? .staleRemoteCache : .remoteCache,
            fetchedAt: entry.fetchedAt,
            expiresAt: expiresAt
        )
    }

    func refresh(keyword: String, limit: Int) async throws -> VideoSearchResult {
        let response = try await searchService.searchVideos(keyword: keyword, limit: limit)
        let cachedVideos = response.videos.map { video in
            CachedVideo(
                id: video.id,
                channelID: video.channelID,
                channelTitle: video.channelTitle,
                title: video.title,
                publishedAt: video.publishedAt,
                videoURL: video.videoURL,
                thumbnailRemoteURL: video.thumbnailURL,
                thumbnailLocalFilename: nil,
                fetchedAt: response.fetchedAt,
                searchableText: [video.title, video.channelTitle, video.id].joined(separator: "\n").lowercased(),
                durationSeconds: video.durationSeconds,
                viewCount: video.viewCount
            )
        }
        await cacheStore.merge(keyword: keyword, videos: cachedVideos, fetchedAt: response.fetchedAt)

        return await loadSnapshot(keyword: keyword, limit: limit, allowExpired: true)
            ?? VideoSearchResult(
                keyword: keyword,
                videos: cachedVideos,
                totalCount: cachedVideos.count,
                source: .remoteAPI,
                fetchedAt: response.fetchedAt,
                expiresAt: response.fetchedAt.addingTimeInterval(cacheLifetime)
            )
    }

    func clear(keyword: String) async {
        await cacheStore.clear(keyword: keyword)
    }

    func status(keyword: String) async -> RemoteSearchCacheStatus {
        await cacheStore.status(keyword: keyword, ttl: cacheLifetime)
    }

    func allVideos(channelID: String) async -> [CachedVideo] {
        await cacheStore.allVideos(channelID: channelID)
    }

    func clearAll() async -> Int {
        await cacheStore.clearAll()
    }
}
