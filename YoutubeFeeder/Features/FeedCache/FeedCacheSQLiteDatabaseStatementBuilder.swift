import Foundation

enum FeedCacheSQLiteDatabaseStatementBuilder {
    static let feedSavedAtMetadataKey = "feed_saved_at"
    static let playlistSnapshotMetadataKey = "feed_playlist_snapshot"
    static let channelNextPageTokensMetadataKey = "feed_channel_next_page_tokens"

    static func pragmaForeignKeysOn() -> String { "PRAGMA foreign_keys = ON;" }
    static func pragmaJournalModeWal() -> String { "PRAGMA journal_mode = WAL;" }
    static func pragmaSynchronousNormal() -> String { "PRAGMA synchronous = NORMAL;" }
    static func beginImmediateTransaction() -> String { "BEGIN IMMEDIATE TRANSACTION;" }
    static func commitTransaction() -> String { "COMMIT TRANSACTION;" }

    static func tableInfo(table: String) -> String {
        "PRAGMA table_info(\(table));"
    }

    static func metadataDateSelect() -> String {
        "SELECT real_value FROM metadata WHERE key = ? LIMIT 1;"
    }

    static func metadataTextSelect() -> String {
        "SELECT text_value FROM metadata WHERE key = ? LIMIT 1;"
    }

    static func metadataDateUpsert() -> String {
        """
        INSERT INTO metadata(key, real_value, text_value)
        VALUES (?, ?, NULL)
        ON CONFLICT(key) DO UPDATE SET real_value = excluded.real_value, text_value = NULL;
        """
    }

    static func metadataTextUpsert() -> String {
        """
        INSERT INTO metadata(key, real_value, text_value)
        VALUES (?, NULL, ?)
        ON CONFLICT(key) DO UPDATE SET real_value = NULL, text_value = excluded.text_value;
        """
    }

    static func metadataDelete() -> String {
        "DELETE FROM metadata WHERE key = ?;"
    }

    static func cachedChannelsSelect() -> String {
        """
        SELECT channel_id, channel_title, channel_display_title, last_attempt_at, last_checked_at, last_success_at,
               latest_published_at, latest_published_at_text, cached_video_count, last_error, etag, last_modified
        FROM cached_channels
        ORDER BY channel_display_title ASC, channel_id ASC;
        """
    }

    static func cachedVideosSelect() -> String {
        """
        SELECT video_id, channel_id, channel_title, channel_display_title, title, published_at, published_at_text,
               video_url, thumbnail_remote_url, thumbnail_local_filename, thumbnail_last_accessed_at, fetched_at, searchable_text,
               duration_seconds, view_count, metadata_badge_text
        FROM cached_videos
        ORDER BY CASE WHEN published_at IS NULL THEN 1 ELSE 0 END, published_at DESC, fetched_at DESC, video_id ASC;
        """
    }

    static func remoteSearchQuerySelect() -> String {
        "SELECT total_count, fetched_at FROM remote_search_queries WHERE keyword = ? LIMIT 1;"
    }

    static func remoteSearchQueryCount() -> String {
        "SELECT COUNT(*) FROM remote_search_queries;"
    }

    static func remoteSearchVideosSelectByKeyword() -> String {
        """
        SELECT video_id, channel_id, channel_title, channel_display_title, title, published_at, published_at_text,
               video_url, thumbnail_remote_url, thumbnail_local_filename, thumbnail_last_accessed_at, fetched_at, searchable_text,
               duration_seconds, view_count, metadata_badge_text
        FROM remote_search_videos
        WHERE keyword = ?
        ORDER BY sort_index ASC;
        """
    }

    static func remoteSearchVideosSelectByChannel() -> String {
        """
        SELECT video_id, channel_id, channel_title, channel_display_title, title, published_at, published_at_text,
               video_url, thumbnail_remote_url, thumbnail_local_filename, fetched_at, searchable_text, duration_seconds,
               view_count, metadata_badge_text
        FROM remote_search_videos
        WHERE channel_id = ?
        ORDER BY CASE WHEN published_at IS NULL THEN 1 ELSE 0 END, published_at DESC, fetched_at DESC, keyword ASC, sort_index ASC;
        """
    }

    static func registeredChannelsSelect() -> String {
        "SELECT channel_id, added_at FROM registered_channels ORDER BY added_at ASC, channel_id ASC;"
    }

    static func registeredChannelsCount() -> String {
        "SELECT COUNT(*) FROM registered_channels;"
    }

    static func clearCachedVideos() -> String { "DELETE FROM cached_videos;" }
    static func clearCachedChannels() -> String { "DELETE FROM cached_channels;" }
    static func clearRemoteSearchVideos() -> String { "DELETE FROM remote_search_videos;" }
    static func clearRemoteSearchQueries() -> String { "DELETE FROM remote_search_queries;" }
    static func clearRegisteredChannels() -> String { "DELETE FROM registered_channels;" }

    static func remoteSearchDeleteByKeyword() -> String {
        "DELETE FROM remote_search_videos WHERE keyword = ?;"
    }

    static func remoteSearchQueryDeleteByKeyword() -> String {
        "DELETE FROM remote_search_queries WHERE keyword = ?;"
    }

    static func registeredChannelDelete() -> String {
        "DELETE FROM registered_channels WHERE channel_id = ?;"
    }

    static func registeredChannelInsert() -> String {
        "INSERT INTO registered_channels(channel_id, added_at) VALUES (?, ?);"
    }

    static func registeredChannelInsertOrIgnore() -> String {
        "INSERT OR IGNORE INTO registered_channels(channel_id, added_at) VALUES (?, ?);"
    }

    static func registeredChannelExists() -> String {
        "SELECT COUNT(*) FROM registered_channels WHERE channel_id = ?;"
    }

    static func remoteSearchQueryUpsert() -> String {
        """
        INSERT INTO remote_search_queries(keyword, total_count, fetched_at)
        VALUES (?, ?, ?)
        ON CONFLICT(keyword) DO UPDATE SET
            total_count = excluded.total_count,
            fetched_at = excluded.fetched_at;
        """
    }

    static func cachedChannelUpsert() -> String {
        """
        INSERT INTO cached_channels(
            channel_id, channel_title, channel_display_title, last_attempt_at, last_checked_at, last_success_at,
            latest_published_at, latest_published_at_text, cached_video_count, last_error, etag, last_modified
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
    }

    static func cachedVideoInsert() -> String {
        """
        INSERT INTO cached_videos(
            video_id, channel_id, channel_title, channel_display_title, title, published_at, published_at_text,
            video_url, thumbnail_remote_url, thumbnail_local_filename, thumbnail_last_accessed_at, fetched_at, searchable_text,
            duration_seconds, view_count, metadata_badge_text
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
    }

    static func remoteSearchVideoInsert() -> String {
        """
        INSERT INTO remote_search_videos(
            keyword, sort_index, video_id, channel_id, channel_title, channel_display_title, title, published_at,
            published_at_text, video_url, thumbnail_remote_url, thumbnail_local_filename, thumbnail_last_accessed_at, fetched_at,
            searchable_text, duration_seconds, view_count, metadata_badge_text
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
    }

    static func updateThumbnailLastAccessedAtCachedVideos() -> String {
        "UPDATE cached_videos SET thumbnail_last_accessed_at = ? WHERE thumbnail_local_filename = ?;"
    }

    static func updateThumbnailLastAccessedAtRemoteSearchVideos() -> String {
        "UPDATE remote_search_videos SET thumbnail_last_accessed_at = ? WHERE thumbnail_local_filename = ?;"
    }

    static func clearThumbnailReferenceCachedVideos() -> String {
        "UPDATE cached_videos SET thumbnail_local_filename = NULL, thumbnail_last_accessed_at = NULL WHERE thumbnail_local_filename = ?;"
    }

    static func clearThumbnailReferenceRemoteSearchVideos() -> String {
        "UPDATE remote_search_videos SET thumbnail_local_filename = NULL, thumbnail_last_accessed_at = NULL WHERE thumbnail_local_filename = ?;"
    }

    static func updateThumbnailCacheCachedVideos() -> String {
        """
        UPDATE cached_videos
        SET thumbnail_remote_url = COALESCE(?, thumbnail_remote_url),
            thumbnail_local_filename = ?
        WHERE video_id = ?;
        """
    }

    static func updateThumbnailCacheRemoteSearchVideos() -> String {
        """
        UPDATE remote_search_videos
        SET thumbnail_remote_url = COALESCE(?, thumbnail_remote_url),
            thumbnail_local_filename = ?
        WHERE video_id = ?;
        """
    }
}
