import Foundation

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

    private let reader: FeedCacheSQLiteDatabaseReader
    private let writer: FeedCacheSQLiteDatabaseWriter

    private init(databaseURL: URL, baseDirectory: URL, fileManager: FileManager) {
        let connection = FeedCacheSQLiteDatabaseConnection(
            databaseURL: databaseURL,
            baseDirectory: baseDirectory,
            fileManager: fileManager
        )
        let reader = FeedCacheSQLiteDatabaseReader(connection: connection)
        let writer = FeedCacheSQLiteDatabaseWriter(connection: connection, reader: reader)
        self.reader = reader
        self.writer = writer
        let schema = FeedCacheSQLiteDatabaseSchema(connection: connection)
        schema.apply()
    }

    deinit {
        close()
    }

    func loadFeedSnapshot() -> FeedCacheSnapshot {
        reader.loadFeedSnapshot()
    }

    func replaceFeedSnapshot(_ snapshot: FeedCacheSnapshot) {
        writer.replaceFeedSnapshot(snapshot)
    }

    func clearFeedCache() {
        writer.clearFeedCache()
    }

    func loadPlaylistSnapshot() -> FeedCachePlaylistSnapshot {
        reader.loadPlaylistSnapshot()
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

    func loadRemoteSearchEntry(keyword: String) -> RemoteVideoSearchCacheEntry? {
        reader.loadRemoteSearchEntry(keyword: keyword)
    }

    func saveRemoteSearchEntry(_ entry: RemoteVideoSearchCacheEntry) {
        writer.saveRemoteSearchEntry(entry)
    }

    func loadAllRemoteSearchVideos(channelID: String) -> [CachedVideo] {
        reader.loadAllRemoteSearchVideos(channelID: channelID)
    }

    func clearRemoteSearch(keyword: String) {
        writer.clearRemoteSearch(keyword: keyword)
    }

    func clearAllRemoteSearch() -> Int {
        writer.clearAllRemoteSearch()
    }

    func updateThumbnailLastAccessedAt(filename: String, accessedAt: Date) {
        writer.updateThumbnailLastAccessedAt(filename: filename, accessedAt: accessedAt)
    }

    func clearThumbnailReference(filename: String) {
        writer.clearThumbnailReference(filename: filename)
    }

    func updateThumbnailCache(videoID: String, remoteURL: URL?, localFilename: String) {
        writer.updateThumbnailCache(videoID: videoID, remoteURL: remoteURL, localFilename: localFilename)
    }

    func loadRegisteredChannels() -> [RegisteredChannel] {
        reader.loadRegisteredChannels()
    }

    func replaceRegisteredChannels(_ records: [RegisteredChannelRecord]) {
        writer.replaceRegisteredChannels(records)
    }

    func addRegisteredChannel(_ channelID: String, addedAt: Date) -> Bool {
        writer.addRegisteredChannel(channelID, addedAt: addedAt)
    }

    func removeRegisteredChannel(_ channelID: String) -> Bool {
        writer.removeRegisteredChannel(channelID)
    }

    func resetRegisteredChannels() -> Int {
        writer.resetRegisteredChannels()
    }

    func close() {
        writer.close()
    }
}
