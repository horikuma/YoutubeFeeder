import Foundation
import SQLite3

final class FeedCacheSQLiteDatabaseReader {
    private let connection: FeedCacheSQLiteDatabaseConnection
    private let statementBuilder: FeedCacheSQLiteDatabaseStatementBuilder.Type

    init(
        connection: FeedCacheSQLiteDatabaseConnection,
        statementBuilder: FeedCacheSQLiteDatabaseStatementBuilder.Type = FeedCacheSQLiteDatabaseStatementBuilder.self
    ) {
        self.connection = connection
        self.statementBuilder = statementBuilder
    }

    func loadFeedSnapshot() -> FeedCacheSnapshot {
        connection.sync {
            FeedCacheSnapshot(
                savedAt: metadataDateInCurrentQueue(for: statementBuilder.feedSavedAtMetadataKey) ?? .distantPast,
                channels: loadCachedChannelsInCurrentQueue(),
                videos: loadCachedVideosInCurrentQueue(),
                channelNextPageTokenByChannelID: loadChannelNextPageTokensInCurrentQueue(),
                playlists: loadPlaylistSnapshotInCurrentQueue()
            )
        }
    }

    func loadPlaylistSnapshot() -> FeedCachePlaylistSnapshot {
        connection.sync {
            loadPlaylistSnapshotInCurrentQueue()
        }
    }

    func loadRemoteSearchEntry(keyword: String) -> RemoteVideoSearchCacheEntry? {
        connection.sync {
            guard let query = remoteSearchQuery(keyword: keyword) else { return nil }
            return RemoteVideoSearchCacheEntry(
                keyword: keyword,
                videos: loadRemoteSearchVideos(keyword: keyword),
                totalCount: query.totalCount,
                fetchedAt: query.fetchedAt
            )
        }
    }

    func loadAllRemoteSearchVideos(channelID: String) -> [CachedVideo] {
        connection.sync {
            var videosByID: [String: CachedVideo] = [:]
            if let statement = connection.prepare(statementBuilder.remoteSearchVideosSelectByChannel()) {
                defer { sqlite3_finalize(statement) }
                bind(channelID, at: 1, in: statement)
                while sqlite3_step(statement) == SQLITE_ROW {
                    let video = cachedVideo(from: statement, includesThumbnailLastAccessedAt: true)
                    if videosByID[video.id] == nil {
                        videosByID[video.id] = video
                    }
                }
            }

            return videosByID.values.sorted(by: cachedVideoSortComparator)
        }
    }

    func loadRegisteredChannels() -> [RegisteredChannel] {
        connection.sync {
            var channels: [RegisteredChannel] = []
            if let statement = connection.prepare(statementBuilder.registeredChannelsSelect()) {
                defer { sqlite3_finalize(statement) }
                while sqlite3_step(statement) == SQLITE_ROW {
                    channels.append(
                        RegisteredChannel(
                            channelID: connection.string(at: 0, in: statement) ?? "",
                            addedAt: connection.date(at: 1, in: statement)
                        )
                    )
                }
            }
            return channels
        }
    }

    func countRemoteSearchQueries() -> Int {
        connection.sync { countRemoteSearchQueriesInCurrentQueue() }
    }

    func countRegisteredChannels() -> Int {
        connection.sync { countRegisteredChannelsInCurrentQueue() }
    }

    func loadChannelNextPageTokens() -> [String: String] {
        connection.sync { loadChannelNextPageTokensInCurrentQueue() }
    }

    func loadPlaylistSnapshotInCurrentQueue() -> FeedCachePlaylistSnapshot {
        guard let text = metadataTextInCurrentQueue(for: statementBuilder.playlistSnapshotMetadataKey),
              let data = text.data(using: .utf8),
              let snapshot = try? connection.decoder.decode(FeedCachePlaylistSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    func loadChannelNextPageTokensInCurrentQueue() -> [String: String] {
        guard let text = metadataTextInCurrentQueue(for: statementBuilder.channelNextPageTokensMetadataKey),
              let data = text.data(using: .utf8),
              let tokens = try? connection.decoder.decode([String: String].self, from: data) else {
            return [:]
        }
        return tokens
    }

    func countRemoteSearchQueriesInCurrentQueue() -> Int {
        connection.scalarInt(statementBuilder.remoteSearchQueryCount())
    }

    func countRegisteredChannelsInCurrentQueue() -> Int {
        connection.scalarInt(statementBuilder.registeredChannelsCount())
    }

    private func loadCachedChannelsInCurrentQueue() -> [CachedChannelState] {
        var channels: [CachedChannelState] = []
        if let statement = connection.prepare(statementBuilder.cachedChannelsSelect()) {
            defer { sqlite3_finalize(statement) }
            while sqlite3_step(statement) == SQLITE_ROW {
                channels.append(cachedChannel(from: statement))
            }
        }
        return channels
    }

    private func loadCachedVideosInCurrentQueue() -> [CachedVideo] {
        var videos: [CachedVideo] = []
        if let statement = connection.prepare(statementBuilder.cachedVideosSelect()) {
            defer { sqlite3_finalize(statement) }
            while sqlite3_step(statement) == SQLITE_ROW {
                videos.append(cachedVideo(from: statement, includesThumbnailLastAccessedAt: true))
            }
        }
        return videos
    }

    private func remoteSearchQuery(keyword: String) -> (totalCount: Int, fetchedAt: Date)? {
        guard let statement = connection.prepare(statementBuilder.remoteSearchQuerySelect()) else { return nil }
        defer { sqlite3_finalize(statement) }
        bind(keyword, at: 1, in: statement)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return (
            totalCount: Int(sqlite3_column_int64(statement, 0)),
            fetchedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))
        )
    }

    private func loadRemoteSearchVideos(keyword: String) -> [CachedVideo] {
        var videos: [CachedVideo] = []
        if let statement = connection.prepare(statementBuilder.remoteSearchVideosSelectByKeyword()) {
            defer { sqlite3_finalize(statement) }
            bind(keyword, at: 1, in: statement)
            while sqlite3_step(statement) == SQLITE_ROW {
                videos.append(cachedVideo(from: statement, includesThumbnailLastAccessedAt: true))
            }
        }
        return videos
    }

    func metadataDateInCurrentQueue(for key: String) -> Date? {
        guard let statement = connection.prepare(statementBuilder.metadataDateSelect()) else { return nil }
        defer { sqlite3_finalize(statement) }
        bind(key, at: 1, in: statement)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return connection.date(at: 0, in: statement)
    }

    func metadataTextInCurrentQueue(for key: String) -> String? {
        guard let statement = connection.prepare(statementBuilder.metadataTextSelect()) else { return nil }
        defer { sqlite3_finalize(statement) }
        bind(key, at: 1, in: statement)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return connection.string(at: 0, in: statement)
    }

    private func cachedVideo(from statement: OpaquePointer, includesThumbnailLastAccessedAt: Bool) -> CachedVideo {
        let channelTitleIndex: Int32 = 2
        let channelDisplayTitleIndex: Int32 = 3
        let titleIndex: Int32 = 4
        let publishedAtIndex: Int32 = 5
        let publishedAtTextIndex: Int32 = 6
        let videoURLIndex: Int32 = 7
        let thumbnailRemoteURLIndex: Int32 = 8
        let thumbnailLocalFilenameIndex: Int32 = 9
        let thumbnailLastAccessedAtIndex: Int32? = includesThumbnailLastAccessedAt ? 10 : nil
        let fetchedAtIndex: Int32 = includesThumbnailLastAccessedAt ? 11 : 10
        let searchableTextIndex: Int32 = includesThumbnailLastAccessedAt ? 12 : 11
        let durationSecondsIndex: Int32 = includesThumbnailLastAccessedAt ? 13 : 12
        let viewCountIndex: Int32 = includesThumbnailLastAccessedAt ? 14 : 13
        let metadataBadgeTextIndex: Int32 = includesThumbnailLastAccessedAt ? 15 : 14

        return CachedVideo(
            id: connection.string(at: 0, in: statement) ?? "",
            channelID: connection.string(at: 1, in: statement) ?? "",
            channelTitle: connection.string(at: channelTitleIndex, in: statement) ?? "",
            channelDisplayTitle: connection.string(at: channelDisplayTitleIndex, in: statement),
            title: connection.string(at: titleIndex, in: statement) ?? "",
            publishedAt: connection.date(at: publishedAtIndex, in: statement),
            publishedAtText: connection.string(at: publishedAtTextIndex, in: statement),
            videoURL: URL(string: connection.string(at: videoURLIndex, in: statement) ?? ""),
            thumbnailRemoteURL: URL(string: connection.string(at: thumbnailRemoteURLIndex, in: statement) ?? ""),
            thumbnailLocalFilename: connection.string(at: thumbnailLocalFilenameIndex, in: statement),
            thumbnailLastAccessedAt: thumbnailLastAccessedAtIndex.flatMap { connection.date(at: $0, in: statement) },
            fetchedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, fetchedAtIndex)),
            searchableText: connection.string(at: searchableTextIndex, in: statement) ?? "",
            durationSeconds: sqlite3_column_type(statement, durationSecondsIndex) == SQLITE_NULL ? nil : Int(sqlite3_column_int64(statement, durationSecondsIndex)),
            viewCount: sqlite3_column_type(statement, viewCountIndex) == SQLITE_NULL ? nil : Int(sqlite3_column_int64(statement, viewCountIndex)),
            metadataBadgeText: connection.string(at: metadataBadgeTextIndex, in: statement)
        )
    }

    private func cachedChannel(from statement: OpaquePointer) -> CachedChannelState {
        CachedChannelState(
            channelID: connection.string(at: 0, in: statement) ?? "",
            channelTitle: connection.string(at: 1, in: statement),
            channelDisplayTitle: connection.string(at: 2, in: statement),
            lastAttemptAt: connection.date(at: 3, in: statement),
            lastCheckedAt: connection.date(at: 4, in: statement),
            lastSuccessAt: connection.date(at: 5, in: statement),
            latestPublishedAt: connection.date(at: 6, in: statement),
            latestPublishedAtText: connection.string(at: 7, in: statement),
            cachedVideoCount: Int(sqlite3_column_int64(statement, 8)),
            lastError: connection.string(at: 9, in: statement),
            etag: connection.string(at: 10, in: statement),
            lastModified: connection.string(at: 11, in: statement)
        )
    }

    private func cachedVideoSortComparator(lhs: CachedVideo, rhs: CachedVideo) -> Bool {
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
