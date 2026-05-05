import Foundation

final class FeedCacheSQLiteDatabaseMetadataWriter {
    private let connection: FeedCacheSQLiteDatabaseConnection
    private let statementBuilder: FeedCacheSQLiteDatabaseStatementBuilder.Type

    init(
        connection: FeedCacheSQLiteDatabaseConnection,
        statementBuilder: FeedCacheSQLiteDatabaseStatementBuilder.Type = FeedCacheSQLiteDatabaseStatementBuilder.self
    ) {
        self.connection = connection
        self.statementBuilder = statementBuilder
    }

    func savePlaylistSnapshot(_ snapshot: FeedCachePlaylistSnapshot) {
        guard let data = try? connection.encoder.encode(snapshot) else {
            deleteMetadata(for: statementBuilder.playlistSnapshotMetadataKey)
            return
        }
        saveMetadataText(String(bytes: data, encoding: .utf8) ?? "", for: statementBuilder.playlistSnapshotMetadataKey)
    }

    func saveChannelNextPageTokens(_ tokens: [String: String]) {
        guard let data = try? connection.encoder.encode(tokens) else {
            deleteMetadata(for: statementBuilder.channelNextPageTokensMetadataKey)
            return
        }
        saveMetadataText(String(bytes: data, encoding: .utf8) ?? "", for: statementBuilder.channelNextPageTokensMetadataKey)
    }

    func saveMetadataDate(_ value: Date, for key: String) {
        connection.execute(
            statementBuilder.metadataDateUpsert(),
            binder: { statement in
                bind(key, at: 1, in: statement)
                bind(value.timeIntervalSince1970, at: 2, in: statement)
            }
        )
    }

    func saveMetadataText(_ value: String, for key: String) {
        connection.execute(
            statementBuilder.metadataTextUpsert(),
            binder: { statement in
                bind(key, at: 1, in: statement)
                bind(value, at: 2, in: statement)
            }
        )
    }

    func deleteMetadata(for key: String) {
        connection.execute(statementBuilder.metadataDelete(), binder: { statement in
            bind(key, at: 1, in: statement)
        })
    }
}
