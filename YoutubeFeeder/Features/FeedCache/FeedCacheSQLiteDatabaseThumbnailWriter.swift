import Foundation

final class FeedCacheSQLiteDatabaseThumbnailWriter {
    private let connection: FeedCacheSQLiteDatabaseConnection
    private let statementBuilder: FeedCacheSQLiteDatabaseStatementBuilder.Type

    init(
        connection: FeedCacheSQLiteDatabaseConnection,
        statementBuilder: FeedCacheSQLiteDatabaseStatementBuilder.Type = FeedCacheSQLiteDatabaseStatementBuilder.self
    ) {
        self.connection = connection
        self.statementBuilder = statementBuilder
    }

    func updateThumbnailLastAccessedAt(filename: String, accessedAt: Date) {
        connection.sync {
            let timestamp = accessedAt.timeIntervalSince1970
            connection.execute(
                statementBuilder.updateThumbnailLastAccessedAtCachedVideos(),
                binder: { statement in
                    bind(timestamp, at: 1, in: statement)
                    bind(filename, at: 2, in: statement)
                }
            )
            connection.execute(
                statementBuilder.updateThumbnailLastAccessedAtRemoteSearchVideos(),
                binder: { statement in
                    bind(timestamp, at: 1, in: statement)
                    bind(filename, at: 2, in: statement)
                }
            )
        }
    }

    func clearThumbnailReference(filename: String) {
        connection.sync {
            connection.execute(
                statementBuilder.clearThumbnailReferenceCachedVideos(),
                binder: { statement in
                    bind(filename, at: 1, in: statement)
                }
            )
            connection.execute(
                statementBuilder.clearThumbnailReferenceRemoteSearchVideos(),
                binder: { statement in
                    bind(filename, at: 1, in: statement)
                }
            )
        }
    }

    func updateThumbnailCache(videoID: String, remoteURL: URL?, localFilename: String) {
        connection.sync {
            connection.execute(
                statementBuilder.updateThumbnailCacheCachedVideos(),
                binder: { statement in
                    bind(remoteURL?.absoluteString, at: 1, in: statement)
                    bind(localFilename, at: 2, in: statement)
                    bind(videoID, at: 3, in: statement)
                }
            )
            connection.execute(
                statementBuilder.updateThumbnailCacheRemoteSearchVideos(),
                binder: { statement in
                    bind(remoteURL?.absoluteString, at: 1, in: statement)
                    bind(localFilename, at: 2, in: statement)
                    bind(videoID, at: 3, in: statement)
                }
            )
        }
    }
}
