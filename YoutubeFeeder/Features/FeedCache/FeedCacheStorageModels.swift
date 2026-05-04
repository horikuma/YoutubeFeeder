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
    let thumbnailLastAccessedAt: Date?
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
        thumbnailLastAccessedAt: Date? = nil,
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
        self.thumbnailLastAccessedAt = thumbnailLastAccessedAt
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
    var registeredChannelIDs: [String] = []
    var maintenanceItems: [ChannelMaintenanceItem] = []
    var channels: [CachedChannelState]
    var videos: [CachedVideo]
    var registeredAtByChannelID: [String: Date?] = [:]
    var channelNextPageTokenByChannelID: [String: String] = [:]
    var playlists: FeedCachePlaylistSnapshot = .empty

    nonisolated static let empty = FeedCacheSnapshot(
        savedAt: .distantPast,
        registeredChannelIDs: [],
        maintenanceItems: [],
        channels: [],
        videos: [],
        registeredAtByChannelID: [:],
        channelNextPageTokenByChannelID: [:],
        playlists: .empty
    )
}

struct FeedCachePlaylistSnapshot: Hashable {
    var playlistsByChannelID: [String: [PlaylistBrowseItem]]
    var playlistPagesByPlaylistID: [String: PlaylistBrowseVideosPage]
    var playlistContinuousPlayURLsByPlaylistID: [String: URL]

    nonisolated static let empty = FeedCachePlaylistSnapshot(
        playlistsByChannelID: [:],
        playlistPagesByPlaylistID: [:],
        playlistContinuousPlayURLsByPlaylistID: [:]
    )
}

extension FeedCacheSnapshot {
    func channelBrowseItems(
        channelIDs: [String]? = nil,
        sortDescriptor: ChannelBrowseSortDescriptor = .default
    ) -> [ChannelBrowseItem] {
        let channelIDs = channelIDs ?? registeredChannelIDs
        let groupedVideos = Dictionary(grouping: videos.filter { !looksLikeShort($0) }, by: \.channelID)
        let states = Dictionary(channels.map { ($0.channelID, $0) }, uniquingKeysWith: { _, rhs in rhs })

        let items = channelIDs.map { channelID in
            let latestVideo = groupedVideos[channelID]?.sorted(by: FeedCacheSnapshot.sortComparator(.publishedDescending)).first
            let state = states[channelID]
            return ChannelBrowseItem(
                id: channelID,
                channelID: channelID,
                channelTitle: state?.channelTitle ?? latestVideo?.channelTitle ?? channelID,
                channelDisplayTitle: state?.channelDisplayTitle ?? latestVideo?.channelDisplayTitle ?? channelID,
                latestPublishedAt: state?.latestPublishedAt ?? latestVideo?.publishedAt,
                latestPublishedAtText: state?.latestPublishedAtText ?? latestVideo?.publishedAtText ?? "投稿日なし",
                registeredAt: registeredAtByChannelID[channelID] ?? nil,
                latestVideo: latestVideo,
                cachedVideoCount: state?.cachedVideoCount ?? groupedVideos[channelID]?.count ?? 0
            )
        }
        return FeedOrdering.sortBrowseItems(items, by: sortDescriptor)
    }

    func videosForChannel(_ channelID: String) -> [CachedVideo] {
        videos
            .filter { $0.channelID == channelID }
            .sorted(by: FeedCacheSnapshot.sortComparator(.publishedDescending))
    }

    func nextPageToken(for channelID: String) -> String? {
        channelNextPageTokenByChannelID[channelID]
    }

    func settingNextPageToken(_ nextPageToken: String?, for channelID: String) -> FeedCacheSnapshot {
        var snapshot = self
        if let nextPageToken {
            snapshot.channelNextPageTokenByChannelID[channelID] = nextPageToken
        } else {
            snapshot.channelNextPageTokenByChannelID[channelID] = nil
        }
        return snapshot
    }

    private static func sortComparator(_ sortOrder: VideoSortOrder) -> (CachedVideo, CachedVideo) -> Bool {
        switch sortOrder {
        case .publishedDescending:
            return { lhs, rhs in
                switch (lhs.publishedAt, rhs.publishedAt) {
                case let (left?, right?) where left != right:
                    return left > right
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                default:
                    return lhs.fetchedAt > rhs.fetchedAt
                }
            }
        }
    }

    private func looksLikeShort(_ video: CachedVideo) -> Bool {
        ShortVideoMaskPolicy.shouldMask(
            durationSeconds: video.durationSeconds,
            videoURL: video.videoURL,
            title: video.title
        )
    }
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
nonisolated extension FeedCachePlaylistSnapshot: Codable {}
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
        case thumbnailLastAccessedAt
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
        let thumbnailLastAccessedAt = try container.decodeIfPresent(Date.self, forKey: .thumbnailLastAccessedAt)
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
            thumbnailLastAccessedAt: thumbnailLastAccessedAt,
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
        try container.encodeIfPresent(thumbnailLastAccessedAt, forKey: .thumbnailLastAccessedAt)
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
