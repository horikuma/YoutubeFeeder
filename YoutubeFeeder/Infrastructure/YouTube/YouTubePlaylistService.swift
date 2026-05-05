import Foundation

struct YouTubePlaylistService {
    nonisolated static let videoDetailsPartParameter = "snippet,contentDetails,statistics,liveStreamingDetails"

    private let transport: YouTubePlaylistServiceTransport

    init(
        dataLoader: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse) = { request in
            try await URLSession.shared.data(for: request)
        }
    ) {
        self.transport = YouTubePlaylistServiceTransport(dataLoader: dataLoader)
    }

    var isConfigured: Bool {
        AppLaunchMode.current.usesMockData || resolvedAPIKey != nil
    }

    func fetchPlaylists(channelID: String, limit: Int = 50) async throws -> [YouTubePlaylistListItem] {
        let logger = AppConsoleLogger.youtubeSearch
        let startedAt = Date()
        var stage = "prepare"

        do {
            if AppLaunchMode.current.usesMockData {
                stage = "mock_response"
                let response = YouTubePlaylistServiceProcessing.mockPlaylistsResponse(channelID: channelID, limit: limit)
                logger.info(
                    "playlist_list_request_complete",
                    metadata: [
                        "channelID": channelID,
                        "items": String(response.count),
                        "source": "mock",
                        "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
                    ]
                )
                return response
            }

            let apiKey = try resolveAPIKey(channelID: channelID, logger: logger)
            stage = "playlist_list"
            let response = try await transport.fetchPlaylists(channelID: channelID, apiKey: apiKey, limit: limit)
            let playlists = response.items.map { item in
                YouTubePlaylistListItem(
                    id: item.id,
                    channelID: item.snippet.channelID,
                    channelTitle: item.snippet.channelTitle,
                    title: item.snippet.title,
                    description: item.snippet.description,
                    publishedAt: item.snippet.publishedAt,
                    itemCount: item.contentDetails?.itemCount,
                    thumbnailURL: YouTubePlaylistServiceProcessing.preferredThumbnailURL(from: item.snippet.thumbnails)
                )
            }
            logger.info(
                "playlist_list_request_complete",
                metadata: [
                    "channelID": channelID,
                    "items": String(playlists.count),
                    "total_results": String(response.pageInfo?.totalResults ?? playlists.count),
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
                ]
            )
            return playlists
        } catch {
            handleFailure(error, stage: stage, channelID: channelID, startedAt: startedAt, logger: logger)
            throw error
        }
    }

    func fetchPlaylistVideosPage(
        playlistID: String,
        pageToken: String?,
        limit: Int = 50
    ) async throws -> YouTubePlaylistVideosPage {
        let logger = AppConsoleLogger.youtubeSearch
        let startedAt = Date()
        var stage = "prepare"

        do {
            if AppLaunchMode.current.usesMockData {
                stage = "mock_response"
                let response = YouTubePlaylistServiceProcessing.mockPlaylistVideosPage(playlistID: playlistID, limit: limit)
                logger.info(
                    "playlist_videos_request_complete",
                    metadata: [
                        "playlist_id": playlistID,
                        "videos": String(response.videos.count),
                        "source": "mock",
                        "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
                    ]
                )
                return response
            }

            let apiKey = try resolveAPIKey(channelID: playlistID, logger: logger)
            stage = "playlist_items"
            let response = try await transport.fetchPlaylistVideosPage(
                playlistID: playlistID,
                pageToken: pageToken,
                apiKey: apiKey,
                limit: limit
            )
            logger.info(
                "playlist_videos_request_complete",
                metadata: [
                    "playlist_id": playlistID,
                    "videos": String(response.videos.count),
                    "next_page_token": response.nextPageToken ?? "",
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
                ]
            )
            return response
        } catch {
            handleFailure(error, stage: stage, channelID: playlistID, startedAt: startedAt, logger: logger)
            throw error
        }
    }

    func continuousPlayURL(playlistID: String) -> URL? {
        URL(string: "https://www.youtube.com/playlist?list=\(playlistID)")
    }

    private func resolveAPIKey(channelID: String, logger: AppConsoleLogger) throws -> String {
        guard let apiKey = resolvedAPIKey else {
            logger.error(
                "config_missing",
                message: YouTubeSearchError.apiKeyMissing.localizedDescription,
                metadata: ["channelID": channelID]
            )
            throw YouTubeSearchError.apiKeyMissing
        }
        return apiKey
    }

    private func handleFailure(_ error: Error, stage: String, channelID: String, startedAt: Date, logger: AppConsoleLogger) {
        let metadata = [
            "channelID": channelID,
            "stage": stage,
            "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt),
            "reason": RemoteSearchErrorPolicy.diagnosticReason(for: error)
        ]
        if RemoteSearchErrorPolicy.isCancellation(error) {
            logger.info("request_cancelled", metadata: metadata)
        } else {
            logger.error(
                "request_failed",
                message: AppConsoleLogger.errorSummary(error),
                metadata: metadata
            )
        }
    }

    private var resolvedAPIKey: String? {
        let environmentKey = ProcessInfo.processInfo.environment["YOUTUBEFEEDER_YOUTUBE_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let environmentKey, !environmentKey.isEmpty {
            return environmentKey
        }

        let plistKey = Bundle.main.object(forInfoDictionaryKey: "YouTubeAPIKey") as? String
        if let plistKey {
            let trimmed = plistKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, !trimmed.hasPrefix("$(") {
                return trimmed
            }
        }

        return nil
    }
}
