import Foundation

struct YouTubeSearchServiceTransport {
    let httpClient: YouTubeSearchServiceHTTPClient

    init(dataLoader: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)) {
        self.httpClient = YouTubeSearchServiceHTTPClient(dataLoader: dataLoader)
    }

    func searchCandidates(
        keyword: String,
        duration: String,
        apiKey: String,
        maxResults: Int
    ) async throws -> [SearchCandidate] {
        let logger = AppConsoleLogger.youtubeSearch
        let startedAt = Date()
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")
        components?.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "q", value: keyword),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "order", value: "date"),
            URLQueryItem(name: "videoDuration", value: duration),
            URLQueryItem(name: "videoEmbeddable", value: "true"),
            URLQueryItem(name: "maxResults", value: String(maxResults))
        ]

        guard let url = components?.url else {
            throw YouTubeSearchError.invalidResponse
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")

        logger.info(
            "candidate_request_start",
            metadata: ["duration": duration, "max_results": String(maxResults), "keyword": AppConsoleLogger.sanitizedKeyword(keyword)]
        )

        let data = try await httpClient.loadData(
            for: request,
            endpoint: "search",
            metadata: ["duration": duration, "max_results": String(maxResults)]
        )
        let response = try httpClient.decodeResponse(SearchListResponse.self, from: data, endpoint: "search", metadata: ["duration": duration])
        let candidates: [SearchCandidate] = response.items.compactMap { item in
            guard let videoID = item.id.videoID else { return nil }
            return SearchCandidate(id: videoID, publishedAt: item.snippet.publishedAt)
        }
        logger.info(
            "candidate_request_complete",
            metadata: [
                "duration": duration,
                "items": String(candidates.count),
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
            ]
        )
        return candidates
    }

    func fetchChannelVideosPage(
        channelID: String,
        pageToken: String?,
        limit: Int,
        apiKey: String
    ) async throws -> YouTubeChannelVideosPage {
        let uploadsPlaylistID = try await fetchChannelUploadsPlaylistID(channelID: channelID, apiKey: apiKey)
        let playlistItems = try await fetchPlaylistItems(
            playlistID: uploadsPlaylistID,
            pageToken: pageToken,
            apiKey: apiKey,
            maxResults: limit
        )
        let videoIDs = playlistItems.items.compactMap(\.contentDetails?.videoID)
        let detailedVideos = try await fetchVideoDetails(videoIDs: videoIDs, apiKey: apiKey)
        let videos = YouTubeSearchServiceProcessing.mergeDetailedVideos(detailedVideos, preferredOrder: videoIDs)
            .filter {
                !ShortVideoMaskPolicy.shouldMask(
                    durationSeconds: $0.durationSeconds,
                    videoURL: $0.videoURL,
                    title: $0.title
                )
            }
        return YouTubeChannelVideosPage(
            videos: videos,
            totalCount: playlistItems.pageInfo?.totalResults ?? videos.count,
            fetchedAt: .now,
            nextPageToken: playlistItems.nextPageToken
        )
    }

    func fetchVideoDetails(videoIDs: [String], apiKey: String) async throws -> [YouTubeSearchVideo] {
        guard !videoIDs.isEmpty else { return [] }

        let logger = AppConsoleLogger.youtubeSearch
        let startedAt = Date()
        var mergedVideos: [YouTubeSearchVideo] = []
        let batches = chunkVideoIDs(videoIDs, size: 50)
        logger.info(
            "video_details_start",
            metadata: ["video_ids": String(videoIDs.count), "batches": String(batches.count)]
        )
        for (index, batch) in batches.enumerated() {
            var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/videos")
            components?.queryItems = [
                URLQueryItem(name: "part", value: YouTubeSearchService.videoDetailsPartParameter),
                URLQueryItem(name: "id", value: batch.joined(separator: ",")),
                URLQueryItem(name: "maxResults", value: String(batch.count))
            ]

            guard let url = components?.url else {
                throw YouTubeSearchError.invalidResponse
            }

            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
            request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")

            let data = try await httpClient.loadData(
                for: request,
                endpoint: "videos",
                metadata: ["batch": "\(index + 1)/\(batches.count)", "ids": String(batch.count)]
            )
            let response = try httpClient.decodeResponse(
                VideoListResponse.self,
                from: data,
                endpoint: "videos",
                metadata: ["batch": "\(index + 1)/\(batches.count)"]
            )
            let videos = YouTubeSearchServiceProcessing.filterPlayableVideos(response.items)
            mergedVideos.append(contentsOf: videos)
            logger.info(
                "video_details_batch_complete",
                metadata: ["batch": "\(index + 1)/\(batches.count)", "videos": String(videos.count)]
            )
        }

        logger.info(
            "video_details_complete",
            metadata: ["videos": String(mergedVideos.count), "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)]
        )
        return mergedVideos
    }

    private func fetchChannelUploadsPlaylistID(channelID: String, apiKey: String) async throws -> String {
        let logger = AppConsoleLogger.youtubeSearch
        let startedAt = Date()
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/channels")
        components?.queryItems = [
            URLQueryItem(name: "part", value: "contentDetails"),
            URLQueryItem(name: "id", value: channelID)
        ]

        guard let url = components?.url else {
            throw YouTubeSearchError.invalidResponse
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")

        logger.info("channel_uploads_request_start", metadata: ["channelID": channelID])

        let data = try await httpClient.loadData(
            for: request,
            endpoint: "channels",
            metadata: ["channelID": channelID]
        )
        let response = try httpClient.decodeResponse(
            ChannelsListResponse.self,
            from: data,
            endpoint: "channels",
            metadata: ["channelID": channelID]
        )
        guard let uploadsPlaylistID = response.items.first?.contentDetails.relatedPlaylists.uploads,
              !uploadsPlaylistID.isEmpty
        else {
            logger.error(
                "channel_uploads_missing",
                message: "チャンネルの uploads プレイリストを取得できませんでした。",
                metadata: [
                    "channelID": channelID,
                    "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
                ]
            )
            throw YouTubeSearchError.invalidResponse
        }

        logger.info(
            "channel_uploads_request_complete",
            metadata: [
                "channelID": channelID,
                "uploads_playlist_id": uploadsPlaylistID,
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
            ]
        )
        return uploadsPlaylistID
    }

    private func fetchPlaylistItems(
        playlistID: String,
        pageToken: String?,
        apiKey: String,
        maxResults: Int
    ) async throws -> PlaylistItemsListResponse {
        let startedAt = Date()
        let logger = AppConsoleLogger.youtubeSearch
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/playlistItems")
        var queryItems = [
            URLQueryItem(name: "part", value: "contentDetails"),
            URLQueryItem(name: "playlistId", value: playlistID),
            URLQueryItem(name: "maxResults", value: String(max(1, min(maxResults, 50))))
        ]
        if let pageToken, !pageToken.isEmpty {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw YouTubeSearchError.invalidResponse
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")

        logger.info(
            "playlist_items_request_start",
            metadata: [
                "playlist_id": playlistID,
                "page_token": pageToken ?? "",
                "max_results": String(max(1, min(maxResults, 50)))
            ]
        )

        let data = try await httpClient.loadData(
            for: request,
            endpoint: "playlistItems",
            metadata: [
                "playlist_id": playlistID,
                "page_token": pageToken ?? "",
                "max_results": String(max(1, min(maxResults, 50)))
            ]
        )
        let response = try httpClient.decodeResponse(
            PlaylistItemsListResponse.self,
            from: data,
            endpoint: "playlistItems",
            metadata: ["playlist_id": playlistID, "page_token": pageToken ?? ""]
        )
        logger.info(
            "playlist_items_request_complete",
            metadata: [
                "playlist_id": playlistID,
                "page_token": pageToken ?? "",
                "items": String(response.items.count),
                "next_page_token": response.nextPageToken ?? "",
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
            ]
        )
        return response
    }

    private func chunkVideoIDs(_ videoIDs: [String], size: Int) -> [[String]] {
        guard size > 0 else { return [videoIDs] }
        var result: [[String]] = []
        var index = 0
        while index < videoIDs.count {
            let nextIndex = min(index + size, videoIDs.count)
            result.append(Array(videoIDs[index ..< nextIndex]))
            index = nextIndex
        }
        return result
    }
}
