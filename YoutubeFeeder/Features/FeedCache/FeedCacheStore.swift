import Foundation

actor FeedCacheStore {
    typealias ThumbnailFetchOperation = @Sendable (URL) async throws -> (Data, HTTPURLResponse)

    let fileManager = FileManager.default
    let encoder = FeedCachePersistenceCoders.makeEncoder()
    let database = FeedCacheSQLiteDatabase.shared()

    let baseDirectory: URL
    let bootstrapFileURL: URL
    let thumbnailsDirectory: URL

    private let reader: FeedCacheStoreReader
    private let writer: FeedCacheStoreWriter

    var lastConsistencyMaintenanceAt: Date?

    init() {
        baseDirectory = FeedCachePaths.baseDirectory(fileManager: fileManager)
        bootstrapFileURL = FeedCachePaths.bootstrapURL(fileManager: fileManager)
        thumbnailsDirectory = FeedCachePaths.thumbnailsDirectory(fileManager: fileManager)
        reader = FeedCacheStoreReader(
            fileManager: fileManager,
            database: database,
            thumbnailsDirectory: thumbnailsDirectory
        )
        writer = FeedCacheStoreWriter(database: database)
    }

    func loadSnapshot() -> FeedCacheSnapshot {
        reader.loadSnapshot(createDirectories: createDirectories)
    }

    func loadPlaylistSnapshot() -> FeedCachePlaylistSnapshot {
        reader.loadPlaylistSnapshot(createDirectories: createDirectories)
    }

    func loadSummary() -> FeedCacheSummary? {
        reader.loadSummary(loadSnapshot: loadSnapshot)
    }

    func summary(for snapshot: FeedCacheSnapshot) -> FeedCacheSummary {
        reader.summary(for: snapshot)
    }

    func loadVideos(query: VideoQuery) -> [CachedVideo] {
        reader.loadVideos(
            query: query,
            loadSnapshot: loadSnapshot,
            matches: matches,
            sortComparator: sortComparator
        )
    }

    func countVideos(query: VideoQuery) -> Int {
        reader.countVideos(query: query, loadSnapshot: loadSnapshot, matches: matches)
    }

    func totalVideoCount() -> Int {
        reader.totalVideoCount(loadSnapshot: loadSnapshot)
    }

    func recordThumbnailReference(filename: String, accessedAt: Date = .now) {
        writer.recordThumbnailReference(filename: filename, accessedAt: accessedAt)
    }

    func clearStoredThumbnailReference(filename: String) {
        writer.clearStoredThumbnailReference(filename: filename)
    }

    func removeThumbnailFile(filename: String) {
        removeThumbnails(named: [filename])
    }

    func thumbnailFileSize(filename: String) -> Int64? {
        reader.thumbnailFileSize(filename: filename)
    }

    func totalThumbnailBytes() -> Int64 {
        reader.totalThumbnailBytes(loadSnapshot: loadSnapshot)
    }

    func loadChannelBrowseItems(channelIDs: [String], registeredAtByChannelID: [String: Date?] = [:]) -> [ChannelBrowseItem] {
        reader.loadChannelBrowseItems(
            channelIDs: channelIDs,
            registeredAtByChannelID: registeredAtByChannelID,
            loadSnapshot: loadSnapshot,
            looksLikeShort: looksLikeShort,
            sortComparator: sortComparator
        )
    }

    func savePlaylistItems(_ items: [PlaylistBrowseItem], channelID: String) {
        writer.savePlaylistItems(items, channelID: channelID)
    }

    func savePlaylistVideosPage(_ page: PlaylistBrowseVideosPage) {
        writer.savePlaylistVideosPage(page)
    }

    func saveChannelNextPageToken(_ nextPageToken: String?, channelID: String) {
        writer.saveChannelNextPageToken(nextPageToken, channelID: channelID)
    }

    func recordFailure(channelID: String, checkedAt: Date, error: String) {
        writer.recordFailure(
            channelID: channelID,
            checkedAt: checkedAt,
            error: error,
            loadSnapshot: loadSnapshot,
            persist: persist
        )
    }

    func recordNotModified(channelID: String, metadata: FeedFetchMetadata) {
        writer.recordNotModified(
            channelID: channelID,
            metadata: metadata,
            loadSnapshot: loadSnapshot,
            persist: persist
        )
    }

    func recordSuccess(channelID: String, videos: [YouTubeVideo], metadata: FeedFetchMetadata) async -> [YouTubeVideo] {
        await writer.recordSuccess(
            channelID: channelID,
            videos: videos,
            metadata: metadata,
            loadSnapshot: loadSnapshot,
            persist: persist
        )
    }
}
