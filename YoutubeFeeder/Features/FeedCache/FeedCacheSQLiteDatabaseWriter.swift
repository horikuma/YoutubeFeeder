import Foundation
import SQLite3

final class FeedCacheSQLiteDatabaseWriter {
    private let connection: FeedCacheSQLiteDatabaseConnection
    private let reader: FeedCacheSQLiteDatabaseReader
    private let statementBuilder: FeedCacheSQLiteDatabaseStatementBuilder.Type
    private let metadataWriter: FeedCacheSQLiteDatabaseMetadataWriter
    private let thumbnailWriter: FeedCacheSQLiteDatabaseThumbnailWriter
    private let registryWriter: FeedCacheSQLiteDatabaseRegistryWriter

    init(
        connection: FeedCacheSQLiteDatabaseConnection,
        reader: FeedCacheSQLiteDatabaseReader,
        statementBuilder: FeedCacheSQLiteDatabaseStatementBuilder.Type = FeedCacheSQLiteDatabaseStatementBuilder.self
    ) {
        self.connection = connection
        self.reader = reader
        self.statementBuilder = statementBuilder
        self.metadataWriter = FeedCacheSQLiteDatabaseMetadataWriter(connection: connection, statementBuilder: statementBuilder)
        self.thumbnailWriter = FeedCacheSQLiteDatabaseThumbnailWriter(connection: connection, statementBuilder: statementBuilder)
        self.registryWriter = FeedCacheSQLiteDatabaseRegistryWriter(connection: connection, statementBuilder: statementBuilder)
    }

    func replaceFeedSnapshot(_ snapshot: FeedCacheSnapshot) {
        connection.sync {
            connection.beginTransaction()
            defer { connection.commitTransaction() }

            connection.execute(statementBuilder.clearCachedVideos())
            connection.execute(statementBuilder.clearCachedChannels())
            metadataWriter.saveMetadataDate(snapshot.savedAt, for: statementBuilder.feedSavedAtMetadataKey)
            snapshot.channels.forEach(insertCachedChannel)
            snapshot.videos.forEach(insertCachedVideo)
            metadataWriter.savePlaylistSnapshot(snapshot.playlists)
        }
    }

    func clearFeedCache() {
        connection.sync {
            connection.beginTransaction()
            defer { connection.commitTransaction() }

            connection.execute(statementBuilder.clearCachedVideos())
            connection.execute(statementBuilder.clearCachedChannels())
            metadataWriter.deleteMetadata(for: statementBuilder.feedSavedAtMetadataKey)
            metadataWriter.deleteMetadata(for: statementBuilder.channelNextPageTokensMetadataKey)
            metadataWriter.deleteMetadata(for: statementBuilder.playlistSnapshotMetadataKey)
        }
    }

    func savePlaylistItems(_ items: [PlaylistBrowseItem], channelID: String) {
        connection.sync {
            var playlistSnapshot = reader.loadPlaylistSnapshotInCurrentQueue()
            playlistSnapshot.playlistsByChannelID[channelID] = items
            for item in items {
                guard let url = continuousPlayURL(for: item.playlistID) else { continue }
                playlistSnapshot.playlistContinuousPlayURLsByPlaylistID[item.playlistID] = url
            }
            metadataWriter.savePlaylistSnapshot(playlistSnapshot)
        }
    }

    func savePlaylistVideosPage(_ page: PlaylistBrowseVideosPage) {
        connection.sync {
            var playlistSnapshot = reader.loadPlaylistSnapshotInCurrentQueue()
            playlistSnapshot.playlistPagesByPlaylistID[page.playlistID] = page
            if let url = continuousPlayURL(for: page.playlistID) {
                playlistSnapshot.playlistContinuousPlayURLsByPlaylistID[page.playlistID] = url
            }
            metadataWriter.savePlaylistSnapshot(playlistSnapshot)
        }
    }

    func saveChannelNextPageToken(_ nextPageToken: String?, channelID: String) {
        connection.sync {
            var tokens = reader.loadChannelNextPageTokensInCurrentQueue()
            if let nextPageToken {
                tokens[channelID] = nextPageToken
            } else {
                tokens[channelID] = nil
            }
            metadataWriter.saveChannelNextPageTokens(tokens)
        }
    }

    func saveRemoteSearchEntry(_ entry: RemoteVideoSearchCacheEntry) {
        connection.sync {
            connection.beginTransaction()
            defer { connection.commitTransaction() }

            let keyword = entry.keyword.trimmingCharacters(in: .whitespacesAndNewlines)
            connection.execute(
                statementBuilder.remoteSearchQueryUpsert(),
                binder: { statement in
                    bind(keyword, at: 1, in: statement)
                    bind(entry.totalCount, at: 2, in: statement)
                    bind(entry.fetchedAt.timeIntervalSince1970, at: 3, in: statement)
                }
            )
            connection.execute(
                statementBuilder.remoteSearchDeleteByKeyword(),
                binder: { statement in bind(keyword, at: 1, in: statement) }
            )
            for (offset, video) in entry.videos.enumerated() {
                insertRemoteSearchVideo(video, keyword: keyword, sortIndex: offset)
            }
        }
    }

    func clearRemoteSearch(keyword: String) {
        connection.sync {
            connection.beginTransaction()
            defer { connection.commitTransaction() }
            connection.execute(statementBuilder.remoteSearchDeleteByKeyword(), binder: { statement in
                bind(keyword, at: 1, in: statement)
            })
            connection.execute(statementBuilder.remoteSearchQueryDeleteByKeyword(), binder: { statement in
                bind(keyword, at: 1, in: statement)
            })
        }
    }

    func clearAllRemoteSearch() -> Int {
        connection.sync {
            let count = reader.countRemoteSearchQueriesInCurrentQueue()
            connection.beginTransaction()
            defer { connection.commitTransaction() }
            connection.execute(statementBuilder.clearRemoteSearchVideos())
            connection.execute(statementBuilder.clearRemoteSearchQueries())
            return count
        }
    }

    func updateThumbnailLastAccessedAt(filename: String, accessedAt: Date) {
        thumbnailWriter.updateThumbnailLastAccessedAt(filename: filename, accessedAt: accessedAt)
    }

    func clearThumbnailReference(filename: String) {
        thumbnailWriter.clearThumbnailReference(filename: filename)
    }

    func updateThumbnailCache(videoID: String, remoteURL: URL?, localFilename: String) {
        thumbnailWriter.updateThumbnailCache(videoID: videoID, remoteURL: remoteURL, localFilename: localFilename)
    }

    func replaceRegisteredChannels(_ records: [RegisteredChannelRecord]) {
        registryWriter.replaceRegisteredChannels(records)
    }

    func addRegisteredChannel(_ channelID: String, addedAt: Date) -> Bool {
        registryWriter.addRegisteredChannel(channelID, addedAt: addedAt)
    }

    func removeRegisteredChannel(_ channelID: String) -> Bool {
        registryWriter.removeRegisteredChannel(channelID)
    }

    func resetRegisteredChannels() -> Int {
        registryWriter.resetRegisteredChannels()
    }

    func close() {
        connection.close()
    }

    private func insertCachedChannel(_ channel: CachedChannelState) {
        connection.execute(
            statementBuilder.cachedChannelUpsert(),
            binder: { statement in
                bind(channel.channelID, at: 1, in: statement)
                bind(channel.channelTitle, at: 2, in: statement)
                bind(channel.channelDisplayTitle, at: 3, in: statement)
                bind(channel.lastAttemptAt?.timeIntervalSince1970, at: 4, in: statement)
                bind(channel.lastCheckedAt?.timeIntervalSince1970, at: 5, in: statement)
                bind(channel.lastSuccessAt?.timeIntervalSince1970, at: 6, in: statement)
                bind(channel.latestPublishedAt?.timeIntervalSince1970, at: 7, in: statement)
                bind(channel.latestPublishedAtText, at: 8, in: statement)
                bind(channel.cachedVideoCount, at: 9, in: statement)
                bind(channel.lastError, at: 10, in: statement)
                bind(channel.etag, at: 11, in: statement)
                bind(channel.lastModified, at: 12, in: statement)
            }
        )
    }

    private func insertCachedVideo(_ video: CachedVideo) {
        connection.execute(
            statementBuilder.cachedVideoInsert(),
            binder: { statement in
                bind(video.id, at: 1, in: statement)
                bind(video.channelID, at: 2, in: statement)
                bind(video.channelTitle, at: 3, in: statement)
                bind(video.channelDisplayTitle, at: 4, in: statement)
                bind(video.title, at: 5, in: statement)
                bind(video.publishedAt?.timeIntervalSince1970, at: 6, in: statement)
                bind(video.publishedAtText, at: 7, in: statement)
                bind(video.videoURL?.absoluteString, at: 8, in: statement)
                bind(video.thumbnailRemoteURL?.absoluteString, at: 9, in: statement)
                bind(video.thumbnailLocalFilename, at: 10, in: statement)
                bind(video.thumbnailLastAccessedAt?.timeIntervalSince1970, at: 11, in: statement)
                bind(video.fetchedAt.timeIntervalSince1970, at: 12, in: statement)
                bind(video.searchableText, at: 13, in: statement)
                bind(video.durationSeconds, at: 14, in: statement)
                bind(video.viewCount, at: 15, in: statement)
                bind(video.metadataBadgeText, at: 16, in: statement)
            }
        )
    }

    private func insertRemoteSearchVideo(_ video: CachedVideo, keyword: String, sortIndex: Int) {
        connection.execute(
            statementBuilder.remoteSearchVideoInsert(),
            binder: { statement in
                bind(keyword, at: 1, in: statement)
                bind(sortIndex, at: 2, in: statement)
                bind(video.id, at: 3, in: statement)
                bind(video.channelID, at: 4, in: statement)
                bind(video.channelTitle, at: 5, in: statement)
                bind(video.channelDisplayTitle, at: 6, in: statement)
                bind(video.title, at: 7, in: statement)
                bind(video.publishedAt?.timeIntervalSince1970, at: 8, in: statement)
                bind(video.publishedAtText, at: 9, in: statement)
                bind(video.videoURL?.absoluteString, at: 10, in: statement)
                bind(video.thumbnailRemoteURL?.absoluteString, at: 11, in: statement)
                bind(video.thumbnailLocalFilename, at: 12, in: statement)
                bind(video.thumbnailLastAccessedAt?.timeIntervalSince1970, at: 13, in: statement)
                bind(video.fetchedAt.timeIntervalSince1970, at: 14, in: statement)
                bind(video.searchableText, at: 15, in: statement)
                bind(video.durationSeconds, at: 16, in: statement)
                bind(video.viewCount, at: 17, in: statement)
                bind(video.metadataBadgeText, at: 18, in: statement)
            }
        )
    }

    private func continuousPlayURL(for playlistID: String) -> URL? {
        URL(string: "https://www.youtube.com/playlist?list=\(playlistID)")
    }

}
