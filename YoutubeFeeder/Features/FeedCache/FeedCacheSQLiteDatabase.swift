import Foundation
import SQLite3

final class FeedCacheSQLiteDatabase {
    private static let registryLock = NSLock()
    private static var sharedByPath: [String: FeedCacheSQLiteDatabase] = [:]

    static func shared(fileManager: FileManager = .default) -> FeedCacheSQLiteDatabase {
        let databaseURL = FeedCachePaths.databaseURL(fileManager: fileManager)
        registryLock.lock()
        defer { registryLock.unlock() }
        if let existing = sharedByPath[databaseURL.path] {
            return existing
        }
        let database = FeedCacheSQLiteDatabase(
            databaseURL: databaseURL,
            baseDirectory: FeedCachePaths.baseDirectory(fileManager: fileManager),
            fileManager: fileManager
        )
        sharedByPath[databaseURL.path] = database
        return database
    }

    static func resetShared(fileManager: FileManager = .default) {
        let databaseURL = FeedCachePaths.databaseURL(fileManager: fileManager)
        registryLock.lock()
        let database = sharedByPath.removeValue(forKey: databaseURL.path)
        registryLock.unlock()
        database?.close()
    }

    private let fileManager: FileManager
    private let databaseURL: URL
    private let baseDirectory: URL
    private let queue: DispatchQueue
    private var database: OpaquePointer?

    private init(databaseURL: URL, baseDirectory: URL, fileManager: FileManager) {
        self.databaseURL = databaseURL
        self.baseDirectory = baseDirectory
        self.fileManager = fileManager
        self.queue = DispatchQueue(label: "Neko.YoutubeFeeder.FeedCacheSQLiteDatabase.\(databaseURL.path)")
        queue.sync {
            openIfNeeded()
            createSchema()
        }
    }

    deinit {
        close()
    }

    func loadFeedSnapshot() -> FeedCacheSnapshot {
        queue.sync {
            FeedCacheSnapshot(
                savedAt: metadataDate(for: "feed_saved_at") ?? .distantPast,
                channels: loadCachedChannels(),
                videos: loadCachedVideos()
            )
        }
    }

    func replaceFeedSnapshot(_ snapshot: FeedCacheSnapshot) {
        queue.sync {
            replaceFeedSnapshotInCurrentQueue(snapshot)
        }
    }

    func clearFeedCache() {
        queue.sync {
            beginTransaction()
            defer { commitTransaction() }

            execute("DELETE FROM cached_videos;")
            execute("DELETE FROM cached_channels;")
            deleteMetadata(for: "feed_saved_at")
        }
    }

    func loadRemoteSearchEntry(keyword: String) -> RemoteVideoSearchCacheEntry? {
        queue.sync {
            guard let query = remoteSearchQuery(keyword: keyword) else { return nil }
            return RemoteVideoSearchCacheEntry(
                keyword: keyword,
                videos: loadRemoteSearchVideos(keyword: keyword),
                totalCount: query.totalCount,
                fetchedAt: query.fetchedAt
            )
        }
    }

    func saveRemoteSearchEntry(_ entry: RemoteVideoSearchCacheEntry) {
        queue.sync {
            saveRemoteSearchEntryInCurrentQueue(entry)
        }
    }

    func loadAllRemoteSearchVideos(channelID: String) -> [CachedVideo] {
        queue.sync {
            var videosByID: [String: CachedVideo] = [:]
            let sql =
                """
                SELECT video_id, channel_id, channel_title, channel_display_title, title, published_at, published_at_text,
                       video_url, thumbnail_remote_url, thumbnail_local_filename, fetched_at, searchable_text, duration_seconds,
                       view_count, metadata_badge_text
                FROM remote_search_videos
                WHERE channel_id = ?
                ORDER BY CASE WHEN published_at IS NULL THEN 1 ELSE 0 END, published_at DESC, fetched_at DESC, keyword ASC, sort_index ASC;
                """
            if let statement = prepare(sql) {
                defer { sqlite3_finalize(statement) }
                bind(channelID, at: 1, in: statement)
                while sqlite3_step(statement) == SQLITE_ROW {
                    let video = cachedVideo(from: statement)
                    if videosByID[video.id] == nil {
                        videosByID[video.id] = video
                    }
                }
            }

            return videosByID.values.sorted(by: cachedVideoSortComparator)
        }
    }

    func clearRemoteSearch(keyword: String) {
        queue.sync {
            beginTransaction()
            defer { commitTransaction() }
            execute("DELETE FROM remote_search_videos WHERE keyword = ?;", binder: { statement in
                bind(keyword, at: 1, in: statement)
            })
            execute("DELETE FROM remote_search_queries WHERE keyword = ?;", binder: { statement in
                bind(keyword, at: 1, in: statement)
            })
        }
    }

    func clearAllRemoteSearch() -> Int {
        queue.sync {
            let count = scalarInt("SELECT COUNT(*) FROM remote_search_queries;")
            beginTransaction()
            defer { commitTransaction() }
            execute("DELETE FROM remote_search_videos;")
            execute("DELETE FROM remote_search_queries;")
            return count
        }
    }

    func loadRegisteredChannels() -> [RegisteredChannel] {
        queue.sync {
            var channels: [RegisteredChannel] = []
            if let statement = prepare("SELECT channel_id, added_at FROM registered_channels ORDER BY added_at ASC, channel_id ASC;") {
                defer { sqlite3_finalize(statement) }
                while sqlite3_step(statement) == SQLITE_ROW {
                    channels.append(
                        RegisteredChannel(
                            channelID: string(at: 0, in: statement) ?? "",
                            addedAt: date(at: 1, in: statement)
                        )
                    )
                }
            }
            return channels
        }
    }

    func replaceRegisteredChannels(_ records: [RegisteredChannelRecord]) {
        queue.sync {
            replaceRegisteredChannelsInCurrentQueue(records)
        }
    }

    func addRegisteredChannel(_ channelID: String, addedAt: Date) -> Bool {
        queue.sync {
            let existing = scalarInt(
                "SELECT COUNT(*) FROM registered_channels WHERE channel_id = ?;",
                binder: { statement in bind(channelID, at: 1, in: statement) }
            )
            guard existing == 0 else { return false }
            execute(
                "INSERT INTO registered_channels(channel_id, added_at) VALUES (?, ?);",
                binder: { statement in
                    bind(channelID, at: 1, in: statement)
                    bind(addedAt.timeIntervalSince1970, at: 2, in: statement)
                }
            )
            return true
        }
    }

    func removeRegisteredChannel(_ channelID: String) -> Bool {
        queue.sync {
            let before = sqlite3_total_changes(database)
            execute("DELETE FROM registered_channels WHERE channel_id = ?;", binder: { statement in
                bind(channelID, at: 1, in: statement)
            })
            return sqlite3_total_changes(database) > before
        }
    }

    func resetRegisteredChannels() -> Int {
        queue.sync {
            let count = scalarInt("SELECT COUNT(*) FROM registered_channels;")
            execute("DELETE FROM registered_channels;")
            return count
        }
    }

    func close() {
        queue.sync {
            guard let database else { return }
            sqlite3_close_v2(database)
            self.database = nil
        }
    }

    private func openIfNeeded() {
        guard database == nil else { return }
        try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(databaseURL.path, &handle, flags, nil) == SQLITE_OK, let handle else {
            return
        }
        database = handle
        execute("PRAGMA foreign_keys = ON;")
        execute("PRAGMA journal_mode = WAL;")
        execute("PRAGMA synchronous = NORMAL;")
    }

    private func createSchema() {
        let statements = [
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
            "CREATE INDEX IF NOT EXISTS idx_remote_search_videos_channel_id ON remote_search_videos(channel_id);",
        ]
        statements.forEach { execute($0) }
    }

    private func loadCachedChannels() -> [CachedChannelState] {
        var channels: [CachedChannelState] = []
        let sql =
            """
            SELECT channel_id, channel_title, channel_display_title, last_attempt_at, last_checked_at, last_success_at,
                   latest_published_at, latest_published_at_text, cached_video_count, last_error, etag, last_modified
            FROM cached_channels
            ORDER BY channel_display_title ASC, channel_id ASC;
            """
        if let statement = prepare(sql) {
            defer { sqlite3_finalize(statement) }
            while sqlite3_step(statement) == SQLITE_ROW {
                channels.append(cachedChannel(from: statement))
            }
        }
        return channels
    }

    private func replaceFeedSnapshotInCurrentQueue(_ snapshot: FeedCacheSnapshot) {
        beginTransaction()
        defer { commitTransaction() }

        execute("DELETE FROM cached_videos;")
        execute("DELETE FROM cached_channels;")
        saveMetadataDate(snapshot.savedAt, for: "feed_saved_at")
        snapshot.channels.forEach(insertCachedChannel)
        snapshot.videos.forEach(insertCachedVideo)
    }

    private func saveRemoteSearchEntryInCurrentQueue(_ entry: RemoteVideoSearchCacheEntry) {
        beginTransaction()
        defer { commitTransaction() }

        let keyword = entry.keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        execute(
            """
            INSERT INTO remote_search_queries(keyword, total_count, fetched_at)
            VALUES (?, ?, ?)
            ON CONFLICT(keyword) DO UPDATE SET
                total_count = excluded.total_count,
                fetched_at = excluded.fetched_at;
            """,
            binder: { statement in
                bind(keyword, at: 1, in: statement)
                bind(entry.totalCount, at: 2, in: statement)
                bind(entry.fetchedAt.timeIntervalSince1970, at: 3, in: statement)
            }
        )
        execute(
            "DELETE FROM remote_search_videos WHERE keyword = ?;",
            binder: { statement in bind(keyword, at: 1, in: statement) }
        )
        for (offset, video) in entry.videos.enumerated() {
            insertRemoteSearchVideo(video, keyword: keyword, sortIndex: offset)
        }
    }

    private func replaceRegisteredChannelsInCurrentQueue(_ records: [RegisteredChannelRecord]) {
        beginTransaction()
        defer { commitTransaction() }

        execute("DELETE FROM registered_channels;")
        for record in records {
            execute(
                "INSERT INTO registered_channels(channel_id, added_at) VALUES (?, ?);",
                binder: { statement in
                    bind(record.channelID, at: 1, in: statement)
                    bind(record.addedAt?.timeIntervalSince1970, at: 2, in: statement)
                }
            )
        }
    }

    private func loadCachedVideos() -> [CachedVideo] {
        var videos: [CachedVideo] = []
        let sql =
            """
            SELECT video_id, channel_id, channel_title, channel_display_title, title, published_at, published_at_text,
                   video_url, thumbnail_remote_url, thumbnail_local_filename, fetched_at, searchable_text,
                   duration_seconds, view_count, metadata_badge_text
            FROM cached_videos
            ORDER BY CASE WHEN published_at IS NULL THEN 1 ELSE 0 END, published_at DESC, fetched_at DESC, video_id ASC;
            """
        if let statement = prepare(sql) {
            defer { sqlite3_finalize(statement) }
            while sqlite3_step(statement) == SQLITE_ROW {
                videos.append(cachedVideo(from: statement))
            }
        }
        return videos
    }

    private func insertCachedChannel(_ channel: CachedChannelState) {
        execute(
            """
            INSERT INTO cached_channels(
                channel_id, channel_title, channel_display_title, last_attempt_at, last_checked_at, last_success_at,
                latest_published_at, latest_published_at_text, cached_video_count, last_error, etag, last_modified
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
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
        execute(
            """
            INSERT INTO cached_videos(
                video_id, channel_id, channel_title, channel_display_title, title, published_at, published_at_text,
                video_url, thumbnail_remote_url, thumbnail_local_filename, fetched_at, searchable_text,
                duration_seconds, view_count, metadata_badge_text
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
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
                bind(video.fetchedAt.timeIntervalSince1970, at: 11, in: statement)
                bind(video.searchableText, at: 12, in: statement)
                bind(video.durationSeconds, at: 13, in: statement)
                bind(video.viewCount, at: 14, in: statement)
                bind(video.metadataBadgeText, at: 15, in: statement)
            }
        )
    }

    private func insertRemoteSearchVideo(_ video: CachedVideo, keyword: String, sortIndex: Int) {
        execute(
            """
            INSERT INTO remote_search_videos(
                keyword, sort_index, video_id, channel_id, channel_title, channel_display_title, title, published_at,
                published_at_text, video_url, thumbnail_remote_url, thumbnail_local_filename, fetched_at,
                searchable_text, duration_seconds, view_count, metadata_badge_text
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
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
                bind(video.fetchedAt.timeIntervalSince1970, at: 13, in: statement)
                bind(video.searchableText, at: 14, in: statement)
                bind(video.durationSeconds, at: 15, in: statement)
                bind(video.viewCount, at: 16, in: statement)
                bind(video.metadataBadgeText, at: 17, in: statement)
            }
        )
    }

    private func loadRemoteSearchVideos(keyword: String) -> [CachedVideo] {
        var videos: [CachedVideo] = []
        let sql =
            """
            SELECT video_id, channel_id, channel_title, channel_display_title, title, published_at, published_at_text,
                   video_url, thumbnail_remote_url, thumbnail_local_filename, fetched_at, searchable_text,
                   duration_seconds, view_count, metadata_badge_text
            FROM remote_search_videos
            WHERE keyword = ?
            ORDER BY sort_index ASC;
            """
        if let statement = prepare(sql) {
            defer { sqlite3_finalize(statement) }
            bind(keyword, at: 1, in: statement)
            while sqlite3_step(statement) == SQLITE_ROW {
                videos.append(cachedVideo(from: statement))
            }
        }
        return videos
    }

    private func remoteSearchQuery(keyword: String) -> (totalCount: Int, fetchedAt: Date)? {
        let sql = "SELECT total_count, fetched_at FROM remote_search_queries WHERE keyword = ? LIMIT 1;"
        guard let statement = prepare(sql) else { return nil }
        defer { sqlite3_finalize(statement) }
        bind(keyword, at: 1, in: statement)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return (
            totalCount: Int(sqlite3_column_int64(statement, 0)),
            fetchedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))
        )
    }

    private func saveMetadataDate(_ value: Date, for key: String) {
        execute(
            """
            INSERT INTO metadata(key, real_value, text_value)
            VALUES (?, ?, NULL)
            ON CONFLICT(key) DO UPDATE SET real_value = excluded.real_value, text_value = NULL;
            """,
            binder: { statement in
                bind(key, at: 1, in: statement)
                bind(value.timeIntervalSince1970, at: 2, in: statement)
            }
        )
    }

    private func saveMetadataText(_ value: String, for key: String) {
        execute(
            """
            INSERT INTO metadata(key, real_value, text_value)
            VALUES (?, NULL, ?)
            ON CONFLICT(key) DO UPDATE SET real_value = NULL, text_value = excluded.text_value;
            """,
            binder: { statement in
                bind(key, at: 1, in: statement)
                bind(value, at: 2, in: statement)
            }
        )
    }

    private func deleteMetadata(for key: String) {
        execute("DELETE FROM metadata WHERE key = ?;", binder: { statement in
            bind(key, at: 1, in: statement)
        })
    }

    private func metadataDate(for key: String) -> Date? {
        let sql = "SELECT real_value FROM metadata WHERE key = ? LIMIT 1;"
        guard let statement = prepare(sql) else { return nil }
        defer { sqlite3_finalize(statement) }
        bind(key, at: 1, in: statement)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return Date(timeIntervalSince1970: sqlite3_column_double(statement, 0))
    }

    private func metadataText(for key: String) -> String? {
        let sql = "SELECT text_value FROM metadata WHERE key = ? LIMIT 1;"
        guard let statement = prepare(sql) else { return nil }
        defer { sqlite3_finalize(statement) }
        bind(key, at: 1, in: statement)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return string(at: 0, in: statement)
    }

    private func beginTransaction() {
        execute("BEGIN IMMEDIATE TRANSACTION;")
    }

    private func commitTransaction() {
        execute("COMMIT TRANSACTION;")
    }

    private func prepare(_ sql: String) -> OpaquePointer? {
        openIfNeeded()
        guard let database else { return nil }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            sqlite3_finalize(statement)
            return nil
        }
        return statement
    }

    private func execute(_ sql: String, binder: ((OpaquePointer) -> Void)? = nil) {
        guard let statement = prepare(sql) else { return }
        defer { sqlite3_finalize(statement) }
        binder?(statement)
        sqlite3_step(statement)
    }

    private func scalarInt(_ sql: String, binder: ((OpaquePointer) -> Void)? = nil) -> Int {
        guard let statement = prepare(sql) else { return 0 }
        defer { sqlite3_finalize(statement) }
        binder?(statement)
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private func cachedVideo(from statement: OpaquePointer) -> CachedVideo {
        CachedVideo(
            id: string(at: 0, in: statement) ?? "",
            channelID: string(at: 1, in: statement) ?? "",
            channelTitle: string(at: 2, in: statement) ?? "",
            channelDisplayTitle: string(at: 3, in: statement),
            title: string(at: 4, in: statement) ?? "",
            publishedAt: date(at: 5, in: statement),
            publishedAtText: string(at: 6, in: statement),
            videoURL: URL(string: string(at: 7, in: statement) ?? ""),
            thumbnailRemoteURL: URL(string: string(at: 8, in: statement) ?? ""),
            thumbnailLocalFilename: string(at: 9, in: statement),
            fetchedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 10)),
            searchableText: string(at: 11, in: statement) ?? "",
            durationSeconds: sqlite3_column_type(statement, 12) == SQLITE_NULL ? nil : Int(sqlite3_column_int64(statement, 12)),
            viewCount: sqlite3_column_type(statement, 13) == SQLITE_NULL ? nil : Int(sqlite3_column_int64(statement, 13)),
            metadataBadgeText: string(at: 14, in: statement)
        )
    }

    private func cachedChannel(from statement: OpaquePointer) -> CachedChannelState {
        CachedChannelState(
            channelID: string(at: 0, in: statement) ?? "",
            channelTitle: string(at: 1, in: statement),
            channelDisplayTitle: string(at: 2, in: statement),
            lastAttemptAt: date(at: 3, in: statement),
            lastCheckedAt: date(at: 4, in: statement),
            lastSuccessAt: date(at: 5, in: statement),
            latestPublishedAt: date(at: 6, in: statement),
            latestPublishedAtText: string(at: 7, in: statement),
            cachedVideoCount: Int(sqlite3_column_int64(statement, 8)),
            lastError: string(at: 9, in: statement),
            etag: string(at: 10, in: statement),
            lastModified: string(at: 11, in: statement)
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

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private func bind(_ value: String?, at index: Int32, in statement: OpaquePointer) {
    guard let value else {
        sqlite3_bind_null(statement, index)
        return
    }
    sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
}

private func bind(_ value: Double?, at index: Int32, in statement: OpaquePointer) {
    guard let value else {
        sqlite3_bind_null(statement, index)
        return
    }
    sqlite3_bind_double(statement, index, value)
}

private func bind(_ value: Int?, at index: Int32, in statement: OpaquePointer) {
    guard let value else {
        sqlite3_bind_null(statement, index)
        return
    }
    sqlite3_bind_int64(statement, index, sqlite3_int64(value))
}

private func string(at index: Int32, in statement: OpaquePointer) -> String? {
    guard let raw = sqlite3_column_text(statement, index) else { return nil }
    return String(cString: raw)
}

private func date(at index: Int32, in statement: OpaquePointer) -> Date? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
    return Date(timeIntervalSince1970: sqlite3_column_double(statement, index))
}
