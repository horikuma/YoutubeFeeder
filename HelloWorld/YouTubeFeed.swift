import Foundation

struct YouTubeVideo: Identifiable, Hashable {
    let id: String
    let title: String
    let channelTitle: String
    let publishedAt: Date?
    let videoURL: URL?
    let thumbnailURL: URL?
}

enum ChannelResource {
    static func loadChannelIDs() -> [String] {
        guard
            let url = Bundle.main.url(forResource: "Channels", withExtension: "txt"),
            let contents = try? String(contentsOf: url, encoding: .utf8)
        else {
            return []
        }

        return contents
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

struct YouTubeFeedService {
    func fetchVideos(for channelID: String) async throws -> [YouTubeVideo] {
        let feedURL = URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=\(channelID)")!
        let request = URLRequest(url: feedURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        let (data, _) = try await URLSession.shared.data(for: request)
        return YouTubeFeedParser().parse(data: data)
            .sorted { lhs, rhs in
                switch (lhs.publishedAt, rhs.publishedAt) {
                case let (left?, right?):
                    return left > right
                case (_?, nil):
                    return true
                default:
                    return false
                }
            }
    }
}

final class YouTubeFeedParser: NSObject, XMLParserDelegate {
    private var videos: [YouTubeVideo] = []
    private var currentElement = ""
    private var currentText = ""

    private var inEntry = false
    private var currentVideoID = ""
    private var currentTitle = ""
    private var currentChannelTitle = ""
    private var currentPublishedAt: Date?
    private var currentVideoURL: URL?
    private var currentThumbnailURL: URL?

    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    func parse(data: Data) -> [YouTubeVideo] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return videos
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String : String] = [:]
    ) {
        currentElement = qName ?? elementName
        currentText = ""

        if currentElement == "entry" {
            inEntry = true
            currentVideoID = ""
            currentTitle = ""
            currentChannelTitle = ""
            currentPublishedAt = nil
            currentVideoURL = nil
            currentThumbnailURL = nil
        }

        guard inEntry else { return }

        if currentElement == "link", let href = attributeDict["href"] {
            currentVideoURL = URL(string: href)
        } else if currentElement == "media:thumbnail", let urlString = attributeDict["url"] {
            currentThumbnailURL = URL(string: urlString)
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let endedElement = qName ?? elementName
        let trimmedText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard inEntry else { return }

        switch endedElement {
        case "yt:videoId":
            currentVideoID = trimmedText
        case "title":
            currentTitle = trimmedText
        case "name":
            currentChannelTitle = trimmedText
        case "published":
            currentPublishedAt = parseDate(trimmedText)
        case "entry":
            videos.append(
                YouTubeVideo(
                    id: currentVideoID.isEmpty ? UUID().uuidString : currentVideoID,
                    title: currentTitle,
                    channelTitle: currentChannelTitle,
                    publishedAt: currentPublishedAt,
                    videoURL: currentVideoURL,
                    thumbnailURL: currentThumbnailURL
                )
            )
            inEntry = false
        default:
            break
        }
    }

    private func parseDate(_ value: String) -> Date? {
        if let date = dateFormatter.date(from: value) {
            return date
        }

        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: value)
    }
}
