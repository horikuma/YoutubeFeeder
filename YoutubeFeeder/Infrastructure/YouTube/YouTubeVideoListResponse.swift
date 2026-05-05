import Foundation

struct VideoListResponse: Decodable {
    let items: [Item]

    struct Item: Decodable {
        let id: String
        let snippet: VideoListSnippet
        let contentDetails: VideoListContentDetails?
        let statistics: VideoListStatistics?
        let liveStreamingDetails: VideoListLiveStreamingDetails?
    }
}

struct VideoListSnippet: Decodable {
    let publishedAt: Date?
    let channelID: String
    let channelTitle: String
    let title: String
    let liveBroadcastContent: String?
    let thumbnails: VideoThumbnails

    private enum CodingKeys: String, CodingKey {
        case publishedAt
        case channelID = "channelId"
        case channelTitle
        case title
        case liveBroadcastContent
        case thumbnails
    }
}

struct VideoListContentDetails: Decodable {
    let duration: String?
}

struct VideoListStatistics: Decodable {
    let viewCount: String?
}

struct VideoListLiveStreamingDetails: Decodable {}

struct VideoThumbnails: Decodable {
    let defaultThumbnail: VideoThumbnail?
    let medium: VideoThumbnail?
    let high: VideoThumbnail?

    private enum CodingKeys: String, CodingKey {
        case defaultThumbnail = "default"
        case medium
        case high
    }
}

struct VideoThumbnail: Decodable {
    let url: URL?
}

extension JSONDecoder {
    static let youtubeAPI: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

func parseDuration(_ rawValue: String) -> Int? {
    guard rawValue.hasPrefix("PT") else { return nil }

    var total = 0
    var buffer = ""
    for character in rawValue.dropFirst(2) {
        if character.isNumber {
            buffer.append(character)
            continue
        }

        guard let value = Int(buffer) else { continue }
        switch character {
        case "H":
            total += value * 3_600
        case "M":
            total += value * 60
        case "S":
            total += value
        default:
            break
        }
        buffer.removeAll(keepingCapacity: true)
    }

    return total > 0 ? total : nil
}
