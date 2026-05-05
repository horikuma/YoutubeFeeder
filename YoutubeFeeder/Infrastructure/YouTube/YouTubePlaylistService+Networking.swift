import Foundation

struct YouTubePlaylistServiceTransport {
    let httpClient: YouTubePlaylistServiceHTTPClient

    init(dataLoader: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)) {
        self.httpClient = YouTubePlaylistServiceHTTPClient(dataLoader: dataLoader)
    }

    func fetchPlaylists(
        channelID: String,
        apiKey: String,
        limit: Int
    ) async throws -> PlaylistsListResponse {
        let startedAt = Date()
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/playlists")
        components?.queryItems = [
            URLQueryItem(name: "part", value: "snippet,contentDetails"),
            URLQueryItem(name: "channelId", value: channelID),
            URLQueryItem(name: "maxResults", value: String(max(1, min(limit, 50))))
        ]

        guard let url = components?.url else {
            throw YouTubeSearchError.invalidResponse
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")

        let data = try await httpClient.loadData(
            for: request,
            endpoint: "playlists",
            metadata: [
                "channel_id": channelID,
                "max_results": String(max(1, min(limit, 50)))
            ]
        )
        let response = try httpClient.decodeResponse(
            PlaylistsListResponse.self,
            from: data,
            endpoint: "playlists",
            metadata: [
                "channel_id": channelID,
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
            ]
        )
        return response
    }

    func fetchPlaylistVideosPage(
        playlistID: String,
        pageToken: String?,
        apiKey: String,
        limit: Int
    ) async throws -> YouTubePlaylistVideosPage {
        let startedAt = Date()
        let playlistItems = try await fetchPlaylistItems(
            playlistID: playlistID,
            pageToken: pageToken,
            apiKey: apiKey,
            maxResults: limit
        )
        let videoIDs = playlistItems.items.compactMap(\.contentDetails?.videoID)
        let detailedVideos = try await fetchVideoDetails(videoIDs: videoIDs, apiKey: apiKey)
        let videos = YouTubePlaylistServiceProcessing.mergeVideos(detailedVideos, preferredOrder: videoIDs)
            .filter {
                !ShortVideoMaskPolicy.shouldMask(
                    durationSeconds: $0.durationSeconds,
                    videoURL: $0.videoURL,
                    title: $0.title
                )
            }
        _ = startedAt
        return YouTubePlaylistVideosPage(
            playlistID: playlistID,
            videos: videos,
            totalCount: playlistItems.pageInfo?.totalResults ?? videos.count,
            fetchedAt: .now,
            nextPageToken: playlistItems.nextPageToken
        )
    }

    private func fetchPlaylistItems(
        playlistID: String,
        pageToken: String?,
        apiKey: String,
        maxResults: Int
    ) async throws -> PlaylistItemsListResponse {
        let startedAt = Date()
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
        _ = startedAt
        return response
    }

    private func fetchVideoDetails(videoIDs: [String], apiKey: String) async throws -> [YouTubePlaylistVideo] {
        guard !videoIDs.isEmpty else { return [] }

        let batches = chunkVideoIDs(videoIDs, size: 50)
        var mergedVideos: [YouTubePlaylistVideo] = []

        for batch in batches {
            var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/videos")
            components?.queryItems = [
                URLQueryItem(name: "part", value: YouTubePlaylistService.videoDetailsPartParameter),
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
                metadata: ["batch": "\(mergedVideos.count + 1)/\(batches.count)", "ids": String(batch.count)]
            )
            let response = try httpClient.decodeResponse(
                VideoListResponse.self,
                from: data,
                endpoint: "videos",
                metadata: ["batch": "\(mergedVideos.count + 1)/\(batches.count)"]
            )
            let videos = YouTubePlaylistServiceProcessing.filterPlayableVideos(response.items)
            mergedVideos.append(contentsOf: videos)
        }

        return mergedVideos
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
