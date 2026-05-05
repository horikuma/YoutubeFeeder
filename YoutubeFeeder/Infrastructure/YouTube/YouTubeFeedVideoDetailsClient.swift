import Foundation

struct YouTubeFeedVideoDetailsClient {
    let transport: YouTubeFeedTransport

    func enrich(_ videos: [YouTubeVideo]) async throws -> [YouTubeVideo] {
        guard let apiKey = transport.resolvedAPIKey else { return videos }
        guard !videos.isEmpty else { return videos }

        var detailsByID: [String: FeedVideoDetail] = [:]
        for batch in YouTubeFeedBatching.chunked(videos.map(\.id), into: 50) {
            var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/videos")
            components?.queryItems = [
                URLQueryItem(name: "part", value: "contentDetails,statistics"),
                URLQueryItem(name: "id", value: batch.joined(separator: ",")),
                URLQueryItem(name: "maxResults", value: String(batch.count))
            ]

            guard let url = components?.url else { continue }
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
            request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
            let (data, _) = try await transport.performScheduledData(for: request)
            let decoder = JSONDecoder()
            let response = try decoder.decode(FeedVideoListResponse.self, from: data)
            for item in response.items {
                detailsByID[item.id] = FeedVideoDetail(
                    durationSeconds: YouTubeFeedVideoMapper.parseDuration(item.contentDetails.duration),
                    viewCount: item.statistics.viewCount.flatMap(Int.init)
                )
            }
        }

        return YouTubeFeedVideoMapper.applyVideoDetails(detailsByID, to: videos)
    }
}
