import Foundation

struct CachedVideo: Identifiable, Hashable {
    let id: String
    let channelID: String
    let channelTitle: String
    let channelDisplayTitle: String
    let title: String
    let publishedAt: Date?
    let publishedAtText: String
    let videoURL: URL?
    let thumbnailRemoteURL: URL?
    let thumbnailLocalFilename: String?
    let fetchedAt: Date
    let searchableText: String
    let durationSeconds: Int?
    let viewCount: Int?
    let metadataBadgeText: String

    init(
        id: String,
        channelID: String,
        channelTitle: String,
        channelDisplayTitle: String? = nil,
        title: String,
        publishedAt: Date?,
        publishedAtText: String? = nil,
        videoURL: URL?,
        thumbnailRemoteURL: URL?,
        thumbnailLocalFilename: String?,
        fetchedAt: Date,
        searchableText: String,
        durationSeconds: Int?,
        viewCount: Int?,
        metadataBadgeText: String? = nil
    ) {
        self.id = id
        self.channelID = channelID
        self.channelTitle = channelTitle
        self.channelDisplayTitle = channelDisplayTitle ?? Self.defaultChannelDisplayTitle(channelTitle: channelTitle, channelID: channelID)
        self.title = title
        self.publishedAt = publishedAt
        self.publishedAtText = publishedAtText ?? Self.defaultPublishedAtText(publishedAt)
        self.videoURL = videoURL
        self.thumbnailRemoteURL = thumbnailRemoteURL
        self.thumbnailLocalFilename = thumbnailLocalFilename
        self.fetchedAt = fetchedAt
        self.searchableText = searchableText
        self.durationSeconds = durationSeconds
        self.viewCount = viewCount
        self.metadataBadgeText = metadataBadgeText ?? AppFormatting.videoTileBadgeText(durationSeconds: durationSeconds, viewCount: viewCount)
    }

    private static func defaultChannelDisplayTitle(channelTitle: String, channelID: String) -> String {
        channelTitle.isEmpty ? channelID : channelTitle
    }

    private static func defaultPublishedAtText(_ publishedAt: Date?) -> String {
        guard let publishedAt else { return "投稿日なし" }
        return AppFormatting.dateTimeFormatter.string(from: publishedAt)
    }
}

struct CachedChannelState: Hashable {
    let channelID: String
    var channelTitle: String?
    var channelDisplayTitle: String
    var lastAttemptAt: Date?
    var lastCheckedAt: Date?
    var lastSuccessAt: Date?
    var latestPublishedAt: Date?
    var latestPublishedAtText: String
    var cachedVideoCount: Int
    var lastError: String?
    var etag: String?
    var lastModified: String?

    init(
        channelID: String,
        channelTitle: String?,
        channelDisplayTitle: String? = nil,
        lastAttemptAt: Date?,
        lastCheckedAt: Date?,
        lastSuccessAt: Date?,
        latestPublishedAt: Date?,
        latestPublishedAtText: String? = nil,
        cachedVideoCount: Int,
        lastError: String?,
        etag: String?,
        lastModified: String?
    ) {
        self.channelID = channelID
        self.channelTitle = channelTitle
        self.channelDisplayTitle = channelDisplayTitle ?? Self.defaultChannelDisplayTitle(channelTitle: channelTitle, channelID: channelID)
        self.lastAttemptAt = lastAttemptAt
        self.lastCheckedAt = lastCheckedAt
        self.lastSuccessAt = lastSuccessAt
        self.latestPublishedAt = latestPublishedAt
        self.latestPublishedAtText = latestPublishedAtText ?? Self.defaultPublishedAtText(latestPublishedAt)
        self.cachedVideoCount = cachedVideoCount
        self.lastError = lastError
        self.etag = etag
        self.lastModified = lastModified
    }

    private static func defaultChannelDisplayTitle(channelTitle: String?, channelID: String) -> String {
        guard let channelTitle, !channelTitle.isEmpty else { return channelID }
        return channelTitle
    }

    private static func defaultPublishedAtText(_ latestPublishedAt: Date?) -> String {
        guard let latestPublishedAt else { return "投稿日なし" }
        return AppFormatting.dateTimeFormatter.string(from: latestPublishedAt)
    }
}

struct FeedCacheSnapshot {
    var savedAt: Date
    var channels: [CachedChannelState]
    var videos: [CachedVideo]

    nonisolated static let empty = FeedCacheSnapshot(savedAt: .distantPast, channels: [], videos: [])
}

struct FeedCacheSummary: Hashable {
    let savedAt: Date?
    let cachedChannelCount: Int
    let cachedVideoCount: Int
    let cachedThumbnailBytes: Int64

    nonisolated static let empty = FeedCacheSummary(
        savedAt: nil,
        cachedChannelCount: 0,
        cachedVideoCount: 0,
        cachedThumbnailBytes: 0
    )
}

nonisolated extension FeedCacheSnapshot: Codable {}
nonisolated extension FeedCacheSummary: Codable {}

extension CachedVideo: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case channelID
        case channelTitle
        case channelDisplayTitle
        case title
        case publishedAt
        case publishedAtText
        case videoURL
        case thumbnailRemoteURL
        case thumbnailLocalFilename
        case fetchedAt
        case searchableText
        case durationSeconds
        case viewCount
        case metadataBadgeText
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let channelID = try container.decode(String.self, forKey: .channelID)
        let channelTitle = try container.decode(String.self, forKey: .channelTitle)
        let title = try container.decode(String.self, forKey: .title)
        let publishedAt = try container.decodeIfPresent(Date.self, forKey: .publishedAt)
        let videoURL = try container.decodeIfPresent(URL.self, forKey: .videoURL)
        let thumbnailRemoteURL = try container.decodeIfPresent(URL.self, forKey: .thumbnailRemoteURL)
        let thumbnailLocalFilename = try container.decodeIfPresent(String.self, forKey: .thumbnailLocalFilename)
        let fetchedAt = try container.decode(Date.self, forKey: .fetchedAt)
        let searchableText = try container.decode(String.self, forKey: .searchableText)
        let durationSeconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds)
        let viewCount = try container.decodeIfPresent(Int.self, forKey: .viewCount)

        self.init(
            id: id,
            channelID: channelID,
            channelTitle: channelTitle,
            channelDisplayTitle: try container.decodeIfPresent(String.self, forKey: .channelDisplayTitle),
            title: title,
            publishedAt: publishedAt,
            publishedAtText: try container.decodeIfPresent(String.self, forKey: .publishedAtText),
            videoURL: videoURL,
            thumbnailRemoteURL: thumbnailRemoteURL,
            thumbnailLocalFilename: thumbnailLocalFilename,
            fetchedAt: fetchedAt,
            searchableText: searchableText,
            durationSeconds: durationSeconds,
            viewCount: viewCount,
            metadataBadgeText: try container.decodeIfPresent(String.self, forKey: .metadataBadgeText)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(channelID, forKey: .channelID)
        try container.encode(channelTitle, forKey: .channelTitle)
        try container.encode(channelDisplayTitle, forKey: .channelDisplayTitle)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(publishedAt, forKey: .publishedAt)
        try container.encode(publishedAtText, forKey: .publishedAtText)
        try container.encodeIfPresent(videoURL, forKey: .videoURL)
        try container.encodeIfPresent(thumbnailRemoteURL, forKey: .thumbnailRemoteURL)
        try container.encodeIfPresent(thumbnailLocalFilename, forKey: .thumbnailLocalFilename)
        try container.encode(fetchedAt, forKey: .fetchedAt)
        try container.encode(searchableText, forKey: .searchableText)
        try container.encodeIfPresent(durationSeconds, forKey: .durationSeconds)
        try container.encodeIfPresent(viewCount, forKey: .viewCount)
        try container.encode(metadataBadgeText, forKey: .metadataBadgeText)
    }
}

extension CachedChannelState: Codable {
    private enum CodingKeys: String, CodingKey {
        case channelID
        case channelTitle
        case channelDisplayTitle
        case lastAttemptAt
        case lastCheckedAt
        case lastSuccessAt
        case latestPublishedAt
        case latestPublishedAtText
        case cachedVideoCount
        case lastError
        case etag
        case lastModified
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let channelID = try container.decode(String.self, forKey: .channelID)
        let channelTitle = try container.decodeIfPresent(String.self, forKey: .channelTitle)
        let latestPublishedAt = try container.decodeIfPresent(Date.self, forKey: .latestPublishedAt)

        self.init(
            channelID: channelID,
            channelTitle: channelTitle,
            channelDisplayTitle: try container.decodeIfPresent(String.self, forKey: .channelDisplayTitle),
            lastAttemptAt: try container.decodeIfPresent(Date.self, forKey: .lastAttemptAt),
            lastCheckedAt: try container.decodeIfPresent(Date.self, forKey: .lastCheckedAt),
            lastSuccessAt: try container.decodeIfPresent(Date.self, forKey: .lastSuccessAt),
            latestPublishedAt: latestPublishedAt,
            latestPublishedAtText: try container.decodeIfPresent(String.self, forKey: .latestPublishedAtText),
            cachedVideoCount: try container.decode(Int.self, forKey: .cachedVideoCount),
            lastError: try container.decodeIfPresent(String.self, forKey: .lastError),
            etag: try container.decodeIfPresent(String.self, forKey: .etag),
            lastModified: try container.decodeIfPresent(String.self, forKey: .lastModified)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(channelID, forKey: .channelID)
        try container.encodeIfPresent(channelTitle, forKey: .channelTitle)
        try container.encode(channelDisplayTitle, forKey: .channelDisplayTitle)
        try container.encodeIfPresent(lastAttemptAt, forKey: .lastAttemptAt)
        try container.encodeIfPresent(lastCheckedAt, forKey: .lastCheckedAt)
        try container.encodeIfPresent(lastSuccessAt, forKey: .lastSuccessAt)
        try container.encodeIfPresent(latestPublishedAt, forKey: .latestPublishedAt)
        try container.encode(latestPublishedAtText, forKey: .latestPublishedAtText)
        try container.encode(cachedVideoCount, forKey: .cachedVideoCount)
        try container.encodeIfPresent(lastError, forKey: .lastError)
        try container.encodeIfPresent(etag, forKey: .etag)
        try container.encodeIfPresent(lastModified, forKey: .lastModified)
    }
}
