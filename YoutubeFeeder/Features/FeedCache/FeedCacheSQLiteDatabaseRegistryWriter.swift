import Foundation

final class FeedCacheSQLiteDatabaseRegistryWriter {
    private let connection: FeedCacheSQLiteDatabaseConnection
    private let statementBuilder: FeedCacheSQLiteDatabaseStatementBuilder.Type

    init(
        connection: FeedCacheSQLiteDatabaseConnection,
        statementBuilder: FeedCacheSQLiteDatabaseStatementBuilder.Type = FeedCacheSQLiteDatabaseStatementBuilder.self
    ) {
        self.connection = connection
        self.statementBuilder = statementBuilder
    }

    func replaceRegisteredChannels(_ records: [RegisteredChannelRecord]) {
        connection.sync {
            connection.beginTransaction()
            defer { connection.commitTransaction() }

            connection.execute(statementBuilder.clearRegisteredChannels())
            for record in records {
                connection.execute(
                    statementBuilder.registeredChannelInsert(),
                    binder: { statement in
                        bind(record.channelID, at: 1, in: statement)
                        bind(record.addedAt?.timeIntervalSince1970, at: 2, in: statement)
                    }
                )
            }
        }
    }

    func addRegisteredChannel(_ channelID: String, addedAt: Date) -> Bool {
        connection.sync {
            let before = connection.totalChanges()
            connection.execute(
                statementBuilder.registeredChannelInsertOrIgnore(),
                binder: { statement in
                    bind(channelID, at: 1, in: statement)
                    bind(addedAt.timeIntervalSince1970, at: 2, in: statement)
                }
            )
            return connection.totalChanges() > before
        }
    }

    func removeRegisteredChannel(_ channelID: String) -> Bool {
        connection.sync {
            let before = connection.totalChanges()
            connection.execute(statementBuilder.registeredChannelDelete(), binder: { statement in
                bind(channelID, at: 1, in: statement)
            })
            return connection.totalChanges() > before
        }
    }

    func resetRegisteredChannels() -> Int {
        connection.sync {
            let count = connection.scalarInt(statementBuilder.registeredChannelsCount())
            connection.execute(statementBuilder.clearRegisteredChannels())
            return count
        }
    }
}
