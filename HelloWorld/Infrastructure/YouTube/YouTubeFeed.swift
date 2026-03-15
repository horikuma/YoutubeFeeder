import Foundation

struct FeedValidationToken: Hashable {
    let etag: String?
    let lastModified: String?
}

struct FeedFetchMetadata: Hashable {
    let checkedAt: Date
    let validationToken: FeedValidationToken
}

enum FeedCheckResult {
    case notModified(FeedFetchMetadata)
    case updated(FeedFetchMetadata)
}

enum FeedFetchResult {
    case notModified(FeedFetchMetadata)
    case updated(videos: [YouTubeVideo], metadata: FeedFetchMetadata)
}

struct YouTubeVideo: Identifiable, Hashable {
    let id: String
    let title: String
    let channelTitle: String
    let publishedAt: Date?
    let videoURL: URL?
    let thumbnailURL: URL?
}

enum ChannelResource {
    static func loadChannelIDs(bundle: Bundle = .main) -> [String] {
        guard
            let url = bundle.url(forResource: "Channels", withExtension: "txt"),
            let contents = try? String(contentsOf: url, encoding: .utf8)
        else {
            return []
        }

        return parseChannelIDs(contents)
    }

    static func parseChannelIDs(_ contents: String) -> [String] {
        contents
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

struct ResolvedYouTubeChannel: Hashable {
    let channelID: String
}

enum ChannelResolutionError: LocalizedError {
    case invalidInput
    case unresolvedChannelID

    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "チャンネル ID、@handle、または YouTube のチャンネル URL を入力してください。"
        case .unresolvedChannelID:
            return "チャンネル ID を解決できませんでした。入力内容を確認してください。"
        }
    }
}

enum YouTubeChannelInput {
    static func directChannelID(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if matchesChannelID(trimmed) {
            return trimmed
        }

        guard let url = URL(string: trimmed), let host = url.host()?.lowercased() else {
            return nil
        }

        guard host.contains("youtube.com") else {
            return nil
        }

        let components = url.pathComponents.filter { $0 != "/" }
        if let channelIndex = components.firstIndex(of: "channel"), components.indices.contains(channelIndex + 1) {
            let candidate = components[channelIndex + 1]
            return matchesChannelID(candidate) ? candidate : nil
        }

        return components.first(where: { matchesChannelID($0) })
    }

    static func lookupURL(from input: String) throws -> URL {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ChannelResolutionError.invalidInput
        }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }

        let handle = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
        guard !handle.isEmpty else {
            throw ChannelResolutionError.invalidInput
        }

        guard let url = URL(string: "https://www.youtube.com/@\(handle)") else {
            throw ChannelResolutionError.invalidInput
        }

        return url
    }

    static func extractChannelID(from html: String) -> String? {
        let patterns = [
            #""externalId":"(UC[0-9A-Za-z_-]{22})""#,
            #""channelId":"(UC[0-9A-Za-z_-]{22})""#,
            #"https://www\.youtube\.com/channel/(UC[0-9A-Za-z_-]{22})"#
        ]

        for pattern in patterns {
            if let match = firstMatch(in: html, pattern: pattern) {
                return match
            }
        }

        return nil
    }

    private static func matchesChannelID(_ value: String) -> Bool {
        value.range(of: #"^UC[0-9A-Za-z_-]{22}$"#, options: .regularExpression) != nil
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard
            let match = regex.firstMatch(in: text, range: range),
            match.numberOfRanges > 1,
            let captureRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }

        return String(text[captureRange])
    }
}

struct YouTubeChannelResolver {
    func resolve(input: String) async throws -> ResolvedYouTubeChannel {
        if let directChannelID = YouTubeChannelInput.directChannelID(from: input) {
            return ResolvedYouTubeChannel(channelID: directChannelID)
        }

        let lookupURL = try YouTubeChannelInput.lookupURL(from: input)
        let (data, _) = try await URLSession.shared.data(from: lookupURL)
        let html = String(decoding: data, as: UTF8.self)

        guard let channelID = YouTubeChannelInput.extractChannelID(from: html) else {
            throw ChannelResolutionError.unresolvedChannelID
        }

        return ResolvedYouTubeChannel(channelID: channelID)
    }
}

struct YouTubeFeedService {
    func checkForUpdates(for channelID: String, validationToken: FeedValidationToken?) async throws -> FeedCheckResult {
        var request = URLRequest(
            url: Self.feedURL(for: channelID),
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 30
        )
        request.httpMethod = "HEAD"
        request.setValue(validationToken?.etag, forHTTPHeaderField: "If-None-Match")
        request.setValue(validationToken?.lastModified, forHTTPHeaderField: "If-Modified-Since")

        let (_, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as? HTTPURLResponse
        let metadata = FeedFetchMetadata(
            checkedAt: .now,
            validationToken: FeedValidationToken(
                etag: httpResponse?.value(forHTTPHeaderField: "ETag") ?? validationToken?.etag,
                lastModified: httpResponse?.value(forHTTPHeaderField: "Last-Modified") ?? validationToken?.lastModified
            )
        )

        if httpResponse?.statusCode == 304 {
            return .notModified(metadata)
        }

        return .updated(metadata)
    }

    func fetchLatestFeed(for channelID: String) async throws -> (videos: [YouTubeVideo], metadata: FeedFetchMetadata) {
        let request = URLRequest(
            url: Self.feedURL(for: channelID),
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 30
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as? HTTPURLResponse
        let metadata = FeedFetchMetadata(
            checkedAt: .now,
            validationToken: FeedValidationToken(
                etag: httpResponse?.value(forHTTPHeaderField: "ETag"),
                lastModified: httpResponse?.value(forHTTPHeaderField: "Last-Modified")
            )
        )

        let videos = YouTubeFeedParser().parse(data: data)
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

        return (videos, metadata)
    }

    func fetchIfNeeded(for channelID: String, validationToken: FeedValidationToken?) async throws -> FeedFetchResult {
        var request = URLRequest(url: Self.feedURL(for: channelID), cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue(validationToken?.etag, forHTTPHeaderField: "If-None-Match")
        request.setValue(validationToken?.lastModified, forHTTPHeaderField: "If-Modified-Since")

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as? HTTPURLResponse
        let metadata = FeedFetchMetadata(
            checkedAt: .now,
            validationToken: FeedValidationToken(
                etag: httpResponse?.value(forHTTPHeaderField: "ETag") ?? validationToken?.etag,
                lastModified: httpResponse?.value(forHTTPHeaderField: "Last-Modified") ?? validationToken?.lastModified
            )
        )

        if httpResponse?.statusCode == 304 {
            return .notModified(metadata)
        }

        let videos = YouTubeFeedParser().parse(data: data)
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

        return .updated(videos: videos, metadata: metadata)
    }

    // YouTube uploads playlists are the long-form uploads feed equivalent.
    static func uploadsPlaylistID(for channelID: String) -> String {
        guard channelID.hasPrefix("UC") else {
            return channelID
        }

        return "UULF" + channelID.dropFirst(2)
    }

    private static func feedURL(for channelID: String) -> URL {
        URL(string: "https://www.youtube.com/feeds/videos.xml?playlist_id=\(uploadsPlaylistID(for: channelID))")!
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
