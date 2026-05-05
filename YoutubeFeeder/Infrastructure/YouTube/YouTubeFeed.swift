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

struct YouTubeFeedService {
    private let checkForUpdatesHandler: (@Sendable (String, FeedValidationToken?) async throws -> FeedCheckResult)?
    private let fetchLatestFeedHandler: (@Sendable (String) async throws -> (videos: [YouTubeVideo], metadata: FeedFetchMetadata))?
    private let transport: YouTubeFeedTransport
    private let videoDetailsClient: YouTubeFeedVideoDetailsClient
    private let fetchPipeline: YouTubeFeedFetchPipeline

    init(
        checkForUpdates: (@Sendable (String, FeedValidationToken?) async throws -> FeedCheckResult)? = nil,
        fetchLatestFeed: (@Sendable (String) async throws -> (videos: [YouTubeVideo], metadata: FeedFetchMetadata))? = nil,
        requestScheduler: RequestScheduler? = nil
    ) {
        let transport = YouTubeFeedTransport(requestScheduler: requestScheduler)
        self.checkForUpdatesHandler = checkForUpdates
        self.fetchLatestFeedHandler = fetchLatestFeed
        self.transport = transport
        self.videoDetailsClient = YouTubeFeedVideoDetailsClient(transport: transport)
        self.fetchPipeline = YouTubeFeedFetchPipeline(
            transport: transport,
            videoDetailsClient: videoDetailsClient
        )
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

        let (_, response) = try await transport.performScheduledData(for: request)
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
        return try await fetchPipeline.fetchLatestFeed(for: channelID)
    }

    func fetchIfNeeded(for channelID: String, validationToken: FeedValidationToken?) async throws -> FeedFetchResult {
        var request = URLRequest(url: Self.feedURL(for: channelID), cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue(validationToken?.etag, forHTTPHeaderField: "If-None-Match")
        request.setValue(validationToken?.lastModified, forHTTPHeaderField: "If-Modified-Since")

        let (data, response) = try await transport.performScheduledData(for: request)
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
}
