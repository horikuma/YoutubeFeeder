import Foundation

struct FeedValidationToken: Hashable {
    let etag: String?
    let lastModified: String?
}

struct FeedFetchMetadata: Hashable {
    let checkedAt: Date
    let validationToken: FeedValidationToken
    let httpStatusCode: Int?

    init(checkedAt: Date, validationToken: FeedValidationToken, httpStatusCode: Int? = nil) {
        self.checkedAt = checkedAt
        self.validationToken = validationToken
        self.httpStatusCode = httpStatusCode
    }
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
    let durationSeconds: Int?
    let viewCount: Int?
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
            return "チャンネル ID、@handle、YouTube のチャンネル URL、または動画 URL を入力してください。"
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

    static func normalizedVideoURL(from input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmed.isEmpty,
            let url = URL(string: trimmed),
            let scheme = url.scheme?.lowercased(),
            let host = url.host()?.lowercased()
        else {
            return nil
        }

        guard scheme == "http" || scheme == "https" else {
            return nil
        }

        if host == "youtu.be" {
            let components = url.pathComponents.filter { $0 != "/" }
            guard let videoID = components.first, !videoID.isEmpty else {
                return nil
            }
            return URL(string: "https://www.youtube.com/watch?v=\(videoID)")
        }

        guard host.contains("youtube.com") else {
            return nil
        }

        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        if url.path == "/watch",
           let videoID = urlComponents.queryItems?.first(where: { $0.name == "v" })?.value,
           !videoID.isEmpty {
            return URL(string: "https://www.youtube.com/watch?v=\(videoID)")
        }

        let components = url.pathComponents.filter { $0 != "/" }
        if components.first == "shorts", components.count > 1 {
            return URL(string: "https://www.youtube.com/watch?v=\(components[1])")
        }

        return nil
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
            #""browseId":"(UC[0-9A-Za-z_-]{22})""#,
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

        let lookupURL: URL
        if let normalizedVideoURL = YouTubeChannelInput.normalizedVideoURL(from: input) {
            lookupURL = normalizedVideoURL
        } else {
            lookupURL = try YouTubeChannelInput.lookupURL(from: input)
        }
        let (data, _) = try await URLSession.shared.data(from: lookupURL)
        let html = String(bytes: data, encoding: .utf8) ?? ""

        guard let channelID = YouTubeChannelInput.extractChannelID(from: html) else {
            throw ChannelResolutionError.unresolvedChannelID
        }

        return ResolvedYouTubeChannel(channelID: channelID)
    }
}

struct YouTubeFeedService {
    private let checkForUpdatesHandler: (@Sendable (String, FeedValidationToken?) async throws -> FeedCheckResult)?
    private let fetchLatestFeedHandler: (@Sendable (String) async throws -> (videos: [YouTubeVideo], metadata: FeedFetchMetadata))?
    private let requestScheduler: RequestScheduler?

    init(
        checkForUpdates: (@Sendable (String, FeedValidationToken?) async throws -> FeedCheckResult)? = nil,
        fetchLatestFeed: (@Sendable (String) async throws -> (videos: [YouTubeVideo], metadata: FeedFetchMetadata))? = nil,
        requestScheduler: RequestScheduler? = nil
    ) {
        self.checkForUpdatesHandler = checkForUpdates
        self.fetchLatestFeedHandler = fetchLatestFeed
        self.requestScheduler = requestScheduler
    }

    private func performScheduledData(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let requestScheduler {
            return try await requestScheduler.enqueue {
                try await URLSession.shared.data(for: request)
            }
        }

        return try await URLSession.shared.data(for: request)
    }

    func checkForUpdates(for channelID: String, validationToken: FeedValidationToken?) async throws -> FeedCheckResult {
        if let checkForUpdatesHandler {
            return try await checkForUpdatesHandler(channelID, validationToken)
        }

        var request = URLRequest(
            url: Self.feedURL(for: channelID),
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 30
        )
        request.httpMethod = "HEAD"
        request.setValue(validationToken?.etag, forHTTPHeaderField: "If-None-Match")
        request.setValue(validationToken?.lastModified, forHTTPHeaderField: "If-Modified-Since")

        let (_, response) = try await performScheduledData(for: request)
        let httpResponse = response as? HTTPURLResponse
        let metadata = FeedFetchMetadata(
            checkedAt: .now,
            validationToken: FeedValidationToken(
                etag: httpResponse?.value(forHTTPHeaderField: "ETag") ?? validationToken?.etag,
                lastModified: httpResponse?.value(forHTTPHeaderField: "Last-Modified") ?? validationToken?.lastModified
            ),
            httpStatusCode: httpResponse?.statusCode
        )

        if httpResponse?.statusCode == 304 {
            return .notModified(metadata)
        }

        return .updated(metadata)
    }

    func fetchLatestFeed(for channelID: String) async throws -> (videos: [YouTubeVideo], metadata: FeedFetchMetadata) {
        if let fetchLatestFeedHandler {
            return try await fetchLatestFeedHandler(channelID)
        }

        let startedAt = Date()
        AppConsoleLogger.feedRefresh.debug(
            "feed_request_started",
            metadata: [
                "channelID": channelID,
                "method": "GET",
                "validation_mode": "unconditional",
                "playlist_id": Self.uploadsPlaylistID(for: channelID)
            ]
        )
        let request = URLRequest(
            url: Self.feedURL(for: channelID),
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 30
        )
        let (data, response) = try await performScheduledData(for: request)
        let httpResponse = response as? HTTPURLResponse
        AppConsoleLogger.feedRefresh.debug(
            "feed_response_received",
            metadata: YouTubeFeedResponseDiagnostics.responseMetadata(
                channelID: channelID,
                httpResponse: httpResponse,
                data: data,
                elapsedMilliseconds: AppConsoleLogger.elapsedMilliseconds(since: startedAt)
            )
        )
        let metadata = FeedFetchMetadata(
            checkedAt: .now,
            validationToken: FeedValidationToken(
                etag: httpResponse?.value(forHTTPHeaderField: "ETag"),
                lastModified: httpResponse?.value(forHTTPHeaderField: "Last-Modified")
            ),
            httpStatusCode: httpResponse?.statusCode
        )

        let parsedVideos = YouTubeFeedParser().parse(data: data)
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
        AppConsoleLogger.feedRefresh.debug(
            "feed_parse_complete",
            metadata: YouTubeFeedResponseDiagnostics.parseMetadata(
                channelID: channelID,
                httpResponse: httpResponse,
                data: data,
                parsedVideos: parsedVideos
            )
        )
        if parsedVideos.isEmpty {
            AppConsoleLogger.feedRefresh.debug(
                "feed_zero_videos_diagnosed",
                metadata: YouTubeFeedResponseDiagnostics.parseMetadata(
                    channelID: channelID,
                    httpResponse: httpResponse,
                    data: data,
                    parsedVideos: parsedVideos
                )
            )
        }

        let videos = if let details = try? await fetchVideoDetails(for: parsedVideos.map(\.id)) {
            applyVideoDetails(details, to: parsedVideos)
        } else {
            parsedVideos
        }
        AppConsoleLogger.feedRefresh.debug(
            "feed_fetch_complete",
            metadata: [
                "channelID": channelID,
                "parsed_videos": String(parsedVideos.count),
                "returned_videos": String(videos.count),
                "elapsed_ms": AppConsoleLogger.elapsedMilliseconds(since: startedAt)
            ]
        )

        return (videos, metadata)
    }

    func fetchIfNeeded(for channelID: String, validationToken: FeedValidationToken?) async throws -> FeedFetchResult {
        var request = URLRequest(url: Self.feedURL(for: channelID), cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue(validationToken?.etag, forHTTPHeaderField: "If-None-Match")
        request.setValue(validationToken?.lastModified, forHTTPHeaderField: "If-Modified-Since")

        let (data, response) = try await performScheduledData(for: request)
        let httpResponse = response as? HTTPURLResponse
        let metadata = FeedFetchMetadata(
            checkedAt: .now,
            validationToken: FeedValidationToken(
                etag: httpResponse?.value(forHTTPHeaderField: "ETag") ?? validationToken?.etag,
                lastModified: httpResponse?.value(forHTTPHeaderField: "Last-Modified") ?? validationToken?.lastModified
            ),
            httpStatusCode: httpResponse?.statusCode
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

    private func fetchVideoDetails(for videoIDs: [String]) async throws -> [String: FeedVideoDetail] {
        guard let apiKey = resolvedAPIKey else { return [:] }
        guard !videoIDs.isEmpty else { return [:] }

        var detailsByID: [String: FeedVideoDetail] = [:]
        for batch in videoIDs.chunked(into: 50) {
            var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/videos")
            components?.queryItems = [
                URLQueryItem(name: "part", value: "contentDetails,statistics"),
                URLQueryItem(name: "id", value: batch.joined(separator: ",")),
                URLQueryItem(name: "maxResults", value: String(batch.count))
            ]

            guard let url = components?.url else { continue }
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
            request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
            let (data, _) = try await performScheduledData(for: request)
            let decoder = JSONDecoder()
            let response = try decoder.decode(FeedVideoListResponse.self, from: data)
            for item in response.items {
                detailsByID[item.id] = FeedVideoDetail(
                    durationSeconds: Self.parseDuration(item.contentDetails.duration),
                    viewCount: item.statistics.viewCount.flatMap(Int.init)
                )
            }
        }

        return detailsByID
    }

    private func applyVideoDetails(_ details: [String: FeedVideoDetail], to videos: [YouTubeVideo]) -> [YouTubeVideo] {
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

    private static func parseDuration(_ value: String) -> Int? {
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

private struct FeedVideoDetail {
    let durationSeconds: Int?
    let viewCount: Int?
}

private struct FeedVideoListResponse: Decodable {
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

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var result: [[Element]] = []
        var index = startIndex
        while index < endIndex {
            let nextIndex = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            result.append(Array(self[index ..< nextIndex]))
            index = nextIndex
        }
        return result
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
