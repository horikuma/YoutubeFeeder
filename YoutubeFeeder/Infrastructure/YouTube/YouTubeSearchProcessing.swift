import Foundation

extension YouTubeSearchService {
    static func mergeCandidates(_ candidates: [SearchCandidate]) -> [SearchCandidate] {
        let deduplicated = candidates.reduce(into: [String: SearchCandidate]()) { partial, candidate in
            guard let existing = partial[candidate.id] else {
                partial[candidate.id] = candidate
                return
            }

            switch (candidate.publishedAt, existing.publishedAt) {
            case let (left?, right?) where left > right:
                partial[candidate.id] = candidate
            case (_?, nil):
                partial[candidate.id] = candidate
            default:
                break
            }
        }

        return deduplicated.values.sorted {
            switch ($0.publishedAt, $1.publishedAt) {
            case let (left?, right?) where left != right:
                return left > right
            case (_?, _?):
                return $0.id < $1.id
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return $0.id < $1.id
            }
        }
    }

    static func filterPlayableVideos(_ items: [VideoListResponse.Item]) -> [YouTubeSearchVideo] {
        items.compactMap { item in
            guard item.snippet.liveBroadcastContent == "none" else { return nil }
            guard item.liveStreamingDetails == nil else { return nil }
            let thumbnailURL = item.snippet.thumbnails.high?.url
                ?? item.snippet.thumbnails.medium?.url
                ?? item.snippet.thumbnails.defaultThumbnail?.url
            return YouTubeSearchVideo(
                id: item.id,
                channelID: item.snippet.channelID,
                channelTitle: item.snippet.channelTitle,
                title: item.snippet.title,
                publishedAt: item.snippet.publishedAt,
                videoURL: URL(string: "https://www.youtube.com/watch?v=\(item.id)"),
                thumbnailURL: thumbnailURL,
                durationSeconds: parseDuration(item.contentDetails.duration),
                viewCount: item.statistics?.viewCount.flatMap(Int.init)
            )
        }
    }

    static func mergeDetailedVideos(_ videos: [YouTubeSearchVideo], preferredOrder: [String]) -> [YouTubeSearchVideo] {
        let order = Dictionary(uniqueKeysWithValues: preferredOrder.enumerated().map { ($1, $0) })
        return videos.sorted { lhs, rhs in
            switch (lhs.publishedAt, rhs.publishedAt) {
            case let (left?, right?) where left != right:
                return left > right
            default:
                return (order[lhs.id] ?? .max) < (order[rhs.id] ?? .max)
            }
        }
    }

    func mockSearchResponse(keyword: String, limit: Int) -> YouTubeSearchResponse {
        let videos = [
            YouTubeSearchVideo(
                id: "remote-refresh-001",
                channelID: "UC_REMOTE_REFRESH",
                channelTitle: "Refresh Channel",
                title: "\(keyword) 最新テスト動画",
                publishedAt: .now.addingTimeInterval(60),
                videoURL: URL(string: "https://www.youtube.com/watch?v=remote-refresh-001"),
                thumbnailURL: URL(string: "https://example.com/remote-refresh-001.jpg"),
                durationSeconds: 1240,
                viewCount: 4242
            ),
            YouTubeSearchVideo(
                id: "remote-refresh-002",
                channelID: "UC_REMOTE_REFRESH",
                channelTitle: "Refresh Channel",
                title: "\(keyword) 追加テスト動画",
                publishedAt: .now,
                videoURL: URL(string: "https://www.youtube.com/watch?v=remote-refresh-002"),
                thumbnailURL: URL(string: "https://example.com/remote-refresh-002.jpg"),
                durationSeconds: 980,
                viewCount: 2024
            )
        ]
        return YouTubeSearchResponse(
            videos: Array(videos.prefix(limit)),
            totalCount: min(videos.count, limit),
            fetchedAt: .now
        )
    }
}
