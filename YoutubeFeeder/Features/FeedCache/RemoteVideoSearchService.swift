import Foundation

struct RemoteVideoSearchService {
    let searchService: YouTubeSearchService

    var isConfigured: Bool {
        searchService.isConfigured
    }

    func refresh(keyword: String, limit: Int) async throws -> RemoteVideoSearchRefreshPayload {
        let logger = AppConsoleLogger.youtubeSearch
        let startedAt = Date()
        let keywordPreview = AppConsoleLogger.sanitizedKeyword(keyword)
        logger.info("remote_refresh_start", metadata: ["keyword": keywordPreview, "limit": String(limit)])
        let response = try await loadRemoteRefreshResponse(
            keyword: keyword,
            limit: limit,
            keywordPreview: keywordPreview,
            startedAt: startedAt,
            logger: logger
        )
        let cachedVideos = cachedVideos(from: response)
        logger.notice(
            "remote_refresh_complete",
            metadata: [
                "keyword": keywordPreview,
                "videos": String(cachedVideos.count),
                "source": VideoSearchSource.remoteAPI.label,
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
            ]
        )
        return RemoteVideoSearchRefreshPayload(
            videos: cachedVideos,
            totalCount: response.totalCount,
            fetchedAt: response.fetchedAt
        )
    }

    private func loadRemoteRefreshResponse(
        keyword: String,
        limit: Int,
        keywordPreview: String,
        startedAt: Date,
        logger: AppConsoleLogger
    ) async throws -> YouTubeSearchResponse {
        do {
            return try await searchService.searchVideos(keyword: keyword, limit: limit)
        } catch {
            let metadata = [
                "keyword": keywordPreview,
                "limit": String(limit),
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
                "reason": RemoteSearchErrorPolicy.diagnosticReason(for: error),
            ]
            if RemoteSearchErrorPolicy.isCancellation(error) {
                logger.notice("remote_refresh_cancelled", metadata: metadata)
            } else {
                logger.error(
                    "remote_refresh_failed",
                    message: AppConsoleLogger.errorSummary(error),
                    metadata: metadata
                )
            }
            throw error
        }
    }

    private func cachedVideos(from response: YouTubeSearchResponse) -> [CachedVideo] {
        response.videos.compactMap { video in
            guard !ShortVideoMaskPolicy.shouldMask(
                durationSeconds: video.durationSeconds,
                videoURL: video.videoURL,
                title: video.title
            ) else {
                return nil
            }
            return CachedVideo(
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
    }

    func refreshChannelVideos(channelID: String, limit: Int = 50) async throws -> RemoteVideoSearchRefreshPayload {
        let response = try await searchService.searchChannelVideos(channelID: channelID, limit: limit)
        let cachedVideos = cachedVideos(from: response)
        return RemoteVideoSearchRefreshPayload(
            videos: cachedVideos,
            totalCount: response.totalCount,
            fetchedAt: response.fetchedAt
        )
    }
}

struct RemoteVideoSearchRefreshPayload: Hashable {
    let videos: [CachedVideo]
    let totalCount: Int
    let fetchedAt: Date
}
