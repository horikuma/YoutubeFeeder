import Foundation
import SQLite3

final class FeedCacheSQLiteDatabaseSchema {
    static let schemaVersion = 2
    static let schemaVersionMetadataKey = "feed_sqlite_schema_version"

    static var schemaStatements: [String] {
        [
            """
            CREATE TABLE IF NOT EXISTS metadata (
                key TEXT PRIMARY KEY,
                real_value REAL,
                text_value TEXT
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS cached_channels (
                channel_id TEXT PRIMARY KEY,
                channel_title TEXT,
                channel_display_title TEXT NOT NULL,
                last_attempt_at REAL,
                last_checked_at REAL,
                last_success_at REAL,
                latest_published_at REAL,
                latest_published_at_text TEXT NOT NULL,
                cached_video_count INTEGER NOT NULL,
                last_error TEXT,
                etag TEXT,
                last_modified TEXT
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS cached_videos (
                video_id TEXT PRIMARY KEY,
                channel_id TEXT NOT NULL,
                channel_title TEXT NOT NULL,
                channel_display_title TEXT NOT NULL,
                title TEXT NOT NULL,
                published_at REAL,
                published_at_text TEXT NOT NULL,
                video_url TEXT,
                thumbnail_remote_url TEXT,
                thumbnail_local_filename TEXT,
                thumbnail_last_accessed_at REAL,
                fetched_at REAL NOT NULL,
                searchable_text TEXT NOT NULL,
                duration_seconds INTEGER,
                view_count INTEGER,
                metadata_badge_text TEXT NOT NULL
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS remote_search_queries (
                keyword TEXT PRIMARY KEY,
                total_count INTEGER NOT NULL,
                fetched_at REAL NOT NULL
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS remote_search_videos (
                keyword TEXT NOT NULL,
                sort_index INTEGER NOT NULL,
                video_id TEXT NOT NULL,
                channel_id TEXT NOT NULL,
                channel_title TEXT NOT NULL,
                channel_display_title TEXT NOT NULL,
                title TEXT NOT NULL,
                published_at REAL,
                published_at_text TEXT NOT NULL,
                video_url TEXT,
                thumbnail_remote_url TEXT,
                thumbnail_local_filename TEXT,
                thumbnail_last_accessed_at REAL,
                fetched_at REAL NOT NULL,
                searchable_text TEXT NOT NULL,
                duration_seconds INTEGER,
                view_count INTEGER,
                metadata_badge_text TEXT NOT NULL,
                PRIMARY KEY(keyword, video_id),
                FOREIGN KEY(keyword) REFERENCES remote_search_queries(keyword) ON DELETE CASCADE
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS registered_channels (
                channel_id TEXT PRIMARY KEY,
                added_at REAL
            );
            """,
            "CREATE INDEX IF NOT EXISTS idx_cached_videos_channel_id ON cached_videos(channel_id);",
            "CREATE INDEX IF NOT EXISTS idx_cached_videos_searchable_text ON cached_videos(searchable_text);",
            "CREATE INDEX IF NOT EXISTS idx_remote_search_videos_keyword_sort ON remote_search_videos(keyword, sort_index);",
            "CREATE INDEX IF NOT EXISTS idx_remote_search_videos_channel_id ON remote_search_videos(channel_id);"
        ]
    }

    private let connection: FeedCacheSQLiteDatabaseConnection
    private let statementBuilder: FeedCacheSQLiteDatabaseStatementBuilder.Type

    init(
        connection: FeedCacheSQLiteDatabaseConnection,
        statementBuilder: FeedCacheSQLiteDatabaseStatementBuilder.Type = FeedCacheSQLiteDatabaseStatementBuilder.self
    ) {
        self.connection = connection
        self.statementBuilder = statementBuilder
    }

    func apply() {
        connection.sync {
            for statement in Self.schemaStatements {
                connection.execute(statement)
            }
            self.migrateSchemaIfNeeded()
            self.saveSchemaVersionIfNeeded()
        }
    }

    private func migrateSchemaIfNeeded() {
        connection.execute(
            Self.addColumnIfMissing(table: "cached_videos", column: "thumbnail_last_accessed_at", definition: "REAL")
        )
        connection.execute(
            Self.addColumnIfMissing(table: "remote_search_videos", column: "thumbnail_last_accessed_at", definition: "REAL")
        )
    }

    private func saveSchemaVersionIfNeeded() {
        guard loadSchemaVersion() < Self.schemaVersion else { return }
        connection.execute(
            self.statementBuilder.metadataTextUpsert(),
            binder: { statement in
                bind(Self.schemaVersionMetadataKey, at: 1, in: statement)
                bind(String(Self.schemaVersion), at: 2, in: statement)
            }
        )
    }

    private func loadSchemaVersion() -> Int {
        guard let statement = connection.prepare(statementBuilder.metadataTextSelect()) else { return 0 }
        defer { sqlite3_finalize(statement) }
        bind(Self.schemaVersionMetadataKey, at: 1, in: statement)
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(connection.string(at: 0, in: statement) ?? "") ?? 0
    }

    private static func addColumnIfMissing(table: String, column: String, definition: String) -> String {
        "ALTER TABLE \(table) ADD COLUMN \(column) \(definition);"
    }
}
