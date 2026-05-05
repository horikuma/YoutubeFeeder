import Foundation

struct FeedVideoDetail {
    let durationSeconds: Int?
    let viewCount: Int?
}

struct FeedVideoListResponse: Decodable {
    let items: [Item]

    struct Item: Decodable {
        let id: String
        let contentDetails: ContentDetails
        let statistics: Statistics
    }

    struct ContentDetails: Decodable {
        let duration: String
    }

    struct Statistics: Decodable {
        let viewCount: String?
    }
}

struct YouTubeFeedVideoMapper {
    static func applyVideoDetails(_ details: [String: FeedVideoDetail], to videos: [YouTubeVideo]) -> [YouTubeVideo] {
        videos.map { video in
            let detail = details[video.id]
            return YouTubeVideo(
                id: video.id,
                title: video.title,
                channelTitle: video.channelTitle,
                publishedAt: video.publishedAt,
                videoURL: video.videoURL,
                thumbnailURL: video.thumbnailURL,
                durationSeconds: detail?.durationSeconds,
                viewCount: detail?.viewCount
            )
        }
    }

    static func parseDuration(_ value: String) -> Int? {
        let pattern = #"PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(value.startIndex..., in: value)
        guard let match = regex.firstMatch(in: value, range: range) else { return nil }

        func component(_ index: Int) -> Int {
            guard
                match.numberOfRanges > index,
                let range = Range(match.range(at: index), in: value)
            else { return 0 }
            return Int(value[range]) ?? 0
        }

        let hours = component(1)
        let minutes = component(2)
        let seconds = component(3)
        return hours * 3600 + minutes * 60 + seconds
    }
}
