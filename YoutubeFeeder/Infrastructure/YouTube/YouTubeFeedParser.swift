import Foundation

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
        attributes attributeDict: [String: String] = [:]
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
        }

        guard inEntry else { return }

        if currentElement == "link", let href = attributeDict["href"] {
            currentVideoURL = URL(string: href)
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
            let parsedVideoID = currentVideoID
            videos.append(
                YouTubeVideo(
                    id: parsedVideoID.isEmpty ? UUID().uuidString : parsedVideoID,
                    title: currentTitle,
                    channelTitle: currentChannelTitle,
                    publishedAt: currentPublishedAt,
                    videoURL: currentVideoURL,
                    thumbnailURL: YouTubeThumbnailCandidates.preferredURL(for: parsedVideoID),
                    durationSeconds: nil,
                    viewCount: nil
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
