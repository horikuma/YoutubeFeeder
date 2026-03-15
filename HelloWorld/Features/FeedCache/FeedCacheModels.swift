import Foundation

enum FeedCachePaths {
    nonisolated static func baseDirectory(fileManager: FileManager = .default) -> URL {
        if let override = ProcessInfo.processInfo.environment["HELLOWORLD_FEEDCACHE_BASE_DIR"],
           !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }

        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return appSupport.appendingPathComponent("FeedCache", isDirectory: true)
    }

    nonisolated static func thumbnailsDirectory(fileManager: FileManager = .default) -> URL {
        baseDirectory(fileManager: fileManager).appendingPathComponent("thumbnails", isDirectory: true)
    }

    nonisolated static func thumbnailURL(filename: String, fileManager: FileManager = .default) -> URL {
        thumbnailsDirectory(fileManager: fileManager).appendingPathComponent(filename)
    }

    nonisolated static func bootstrapURL(fileManager: FileManager = .default) -> URL {
        baseDirectory(fileManager: fileManager).appendingPathComponent("maintenance-bootstrap.json")
    }

    nonisolated static func cacheURL(fileManager: FileManager = .default) -> URL {
        baseDirectory(fileManager: fileManager).appendingPathComponent("cache.json")
    }

    nonisolated static func channelRegistryURL(fileManager: FileManager = .default) -> URL {
        baseDirectory(fileManager: fileManager).appendingPathComponent("channel-registry.json")
    }

    nonisolated static func remoteSearchCacheURL(keyword: String, fileManager: FileManager = .default) -> URL {
        let sanitizedKeyword = keyword
            .precomposedStringWithCompatibilityMapping
            .lowercased()
            .replacingOccurrences(of: "[^0-9a-z]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let filename = sanitizedKeyword.isEmpty ? "remote-search.json" : "remote-search-\(sanitizedKeyword).json"
        return baseDirectory(fileManager: fileManager).appendingPathComponent(filename)
    }
}

struct CachedVideo: Identifiable, Hashable {
    let id: String
    let channelID: String
    let channelTitle: String
    let title: String
    let publishedAt: Date?
    let videoURL: URL?
    let thumbnailRemoteURL: URL?
    let thumbnailLocalFilename: String?
    let fetchedAt: Date
    let searchableText: String
}

struct CachedChannelState: Hashable {
    let channelID: String
    var channelTitle: String?
    var lastAttemptAt: Date?
    var lastCheckedAt: Date?
    var lastSuccessAt: Date?
    var latestPublishedAt: Date?
    var cachedVideoCount: Int
    var lastError: String?
    var etag: String?
    var lastModified: String?
}

struct FeedCacheSnapshot {
    var savedAt: Date
    var channels: [CachedChannelState]
    var videos: [CachedVideo]

    nonisolated static let empty = FeedCacheSnapshot(savedAt: .distantPast, channels: [], videos: [])
}

struct CacheProgress {
    let totalChannels: Int
    let cachedChannels: Int
    let cachedVideos: Int
    let cachedThumbnails: Int
    let currentChannelID: String?
    let currentChannelNumber: Int?
    let lastUpdatedAt: Date?
    let isRunning: Bool
    let lastError: String?
}

struct RefreshStageProgress: Hashable {
    let title: String
    let completed: Int
    let total: Int
    let activeCalls: Int
    let callsPerSecond: Int

    nonisolated static func idle(title: String, callsPerSecond: Int) -> RefreshStageProgress {
        RefreshStageProgress(title: title, completed: 0, total: 0, activeCalls: 0, callsPerSecond: callsPerSecond)
    }
}

struct CacheRefreshProgress: Hashable {
    var isRefreshing: Bool
    var checkStage: RefreshStageProgress
    var fetchStage: RefreshStageProgress
    var thumbnailStage: RefreshStageProgress

    nonisolated static let idle = CacheRefreshProgress(
        isRefreshing: false,
        checkStage: .idle(title: "フィード更新確認", callsPerSecond: 3),
        fetchStage: .idle(title: "更新チャンネル取得", callsPerSecond: 1),
        thumbnailStage: .idle(title: "サムネイル取得", callsPerSecond: 1)
    )
}

enum ChannelFreshness: String {
    case neverFetched
    case fresh
    case stale

    var label: String {
        switch self {
        case .neverFetched: return "未取得"
        case .fresh: return "最新"
        case .stale: return "未更新"
        }
    }
}

struct ChannelMaintenanceItem: Identifiable, Hashable {
    let id: String
    let channelID: String
    let channelTitle: String?
    let lastSuccessAt: Date?
    let lastCheckedAt: Date?
    let latestPublishedAt: Date?
    let cachedVideoCount: Int
    let lastError: String?
    let freshness: ChannelFreshness
}

struct ChannelBrowseItem: Identifiable, Hashable {
    let id: String
    let channelID: String
    let channelTitle: String
    let latestPublishedAt: Date?
    let registeredAt: Date?
    let latestVideo: CachedVideo?
    let cachedVideoCount: Int
}

struct VideoSearchResult: Hashable {
    let keyword: String
    let videos: [CachedVideo]
    let totalCount: Int
    let source: VideoSearchSource
    let fetchedAt: Date?
    let expiresAt: Date?
    let errorMessage: String?

    init(
        keyword: String,
        videos: [CachedVideo],
        totalCount: Int,
        source: VideoSearchSource = .localCache,
        fetchedAt: Date? = nil,
        expiresAt: Date? = nil,
        errorMessage: String? = nil
    ) {
        self.keyword = keyword
        self.videos = videos
        self.totalCount = totalCount
        self.source = source
        self.fetchedAt = fetchedAt
        self.expiresAt = expiresAt
        self.errorMessage = errorMessage
    }
}

enum VideoSearchSource: String, Hashable {
    case localCache
    case remoteAPI
    case remoteCache
    case staleRemoteCache
    case mockData

    var label: String {
        switch self {
        case .localCache:
            return "キャッシュ"
        case .remoteAPI:
            return "YouTube"
        case .remoteCache:
            return "検索キャッシュ"
        case .staleRemoteCache:
            return "古い検索キャッシュ"
        case .mockData:
            return "UIテスト"
        }
    }
}

struct RemoteVideoSearchCacheEntry: Hashable {
    let keyword: String
    let videos: [CachedVideo]
    let totalCount: Int
    let fetchedAt: Date
}

struct RemoteSearchCacheStatus: Hashable {
    let keyword: String
    let isFresh: Bool
    let totalCount: Int
    let fetchedAt: Date?
    let expiresAt: Date?
    let exists: Bool

    nonisolated static func empty(keyword: String) -> RemoteSearchCacheStatus {
        RemoteSearchCacheStatus(keyword: keyword, isFresh: false, totalCount: 0, fetchedAt: nil, expiresAt: nil, exists: false)
    }

    var label: String {
        guard exists else { return "未作成" }
        return isFresh ? "有効" : "期限切れ"
    }
}

struct HomeSystemStatus: Hashable {
    let registeredChannelCount: Int
    let cachedVideoCount: Int
    let cacheLastUpdatedAt: Date?
    let apiKeyConfigured: Bool
    let searchCacheStatus: RemoteSearchCacheStatus

    nonisolated static func empty(keyword: String) -> HomeSystemStatus {
        HomeSystemStatus(
            registeredChannelCount: 0,
            cachedVideoCount: 0,
            cacheLastUpdatedAt: nil,
            apiKeyConfigured: false,
            searchCacheStatus: .empty(keyword: keyword)
        )
    }
}

enum ChannelRegistrationStatus: Hashable {
    case added
    case alreadyRegistered
}

struct ChannelRegistrationFeedback: Hashable {
    let status: ChannelRegistrationStatus
    let channelID: String
    let channelTitle: String
    let latestVideoTitle: String?
    let latestPublishedAt: Date?
    let cachedVideoCount: Int
    let latestFeedError: String?
}

struct ChannelRemovalFeedback: Identifiable, Hashable {
    let channelID: String
    let channelTitle: String
    let removedVideoCount: Int
    let removedThumbnailCount: Int

    var id: String { channelID }

    var title: String {
        "チャンネルを削除しました"
    }

    var detail: String {
        "\(channelTitle) を削除し、動画 \(removedVideoCount) 件・サムネイル \(removedThumbnailCount) 件を整理"
    }
}

struct CacheConsistencyMaintenanceResult: Hashable {
    let removedVideoCount: Int
    let removedThumbnailCount: Int
}

enum ChannelRegistryTransferAction: Hashable {
    case export
    case `import`
}

struct ChannelRegistryTransferFeedback: Hashable {
    let action: ChannelRegistryTransferAction
    let backend: ChannelRegistryTransferBackend
    let channelCount: Int
    let path: String
    let refreshMessage: String?

    var title: String {
        switch action {
        case .export:
            return "バックアップを書き出しました"
        case .import:
            return "バックアップを読み込みました"
        }
    }

    var detail: String {
        switch action {
        case .export:
            return "\(backend.shortLabel)へチャンネル \(channelCount) 件を保存"
        case .import:
            return "\(backend.shortLabel)からチャンネル \(channelCount) 件を反映"
        }
    }
}

struct FeedBootstrapSnapshot {
    var progress: CacheProgress
    var maintenanceItems: [ChannelMaintenanceItem]
}

struct RegisteredChannelRecord: Codable, Hashable {
    let channelID: String
    let addedAt: Date?
}

struct RegisteredChannel: Hashable {
    let channelID: String
    let addedAt: Date?
}

struct ChannelRegistrySnapshot: Codable {
    var channels: [RegisteredChannelRecord]

    init(channels: [RegisteredChannelRecord]) {
        self.channels = channels
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let snapshot = try? container.decode(LegacySnapshot.self) {
            channels = snapshot.customChannelIDs.map {
                RegisteredChannelRecord(channelID: $0, addedAt: nil)
            }
            return
        }

        self = try container.decode(CurrentSnapshot.self).snapshot
    }

    func encode(to encoder: Encoder) throws {
        try CurrentSnapshot(snapshot: self).encode(to: encoder)
    }

    private struct LegacySnapshot: Codable {
        let customChannelIDs: [String]
    }

    private struct CurrentSnapshot: Codable {
        let channels: [RegisteredChannelRecord]

        private enum CodingKeys: String, CodingKey {
            case channels
            case customChannels
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let channels = try container.decodeIfPresent([RegisteredChannelRecord].self, forKey: .channels) {
                self.channels = channels
            } else {
                let legacyChannels = try container.decode([RegisteredChannelRecord].self, forKey: .customChannels)
                self.channels = legacyChannels
            }
        }

        init(snapshot: ChannelRegistrySnapshot) {
            channels = snapshot.channels
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(channels, forKey: .channels)
        }

        var snapshot: ChannelRegistrySnapshot {
            ChannelRegistrySnapshot(channels: channels)
        }
    }
}

struct ChannelRegistryTransferDocument: Codable, Hashable {
    let formatVersion: Int
    let exportedAt: Date
    let channels: [RegisteredChannelRecord]

    private enum CodingKeys: String, CodingKey {
        case formatVersion
        case exportedAt
        case channels
        case customChannels
    }

    init(formatVersion: Int = 2, exportedAt: Date = .now, channels: [RegisteredChannelRecord]) {
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.channels = channels
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let formatVersion = try? container.decode(Int.self, forKey: .formatVersion),
           let exportedAt = try? container.decode(Date.self, forKey: .exportedAt),
           let channels = try? container.decode([RegisteredChannelRecord].self, forKey: .channels) {
            self.init(formatVersion: formatVersion, exportedAt: exportedAt, channels: channels)
            return
        }

        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let formatVersion = try? container.decode(Int.self, forKey: .formatVersion),
           let exportedAt = try? container.decode(Date.self, forKey: .exportedAt),
           let legacyChannels = try? container.decode([RegisteredChannelRecord].self, forKey: .customChannels) {
            self.init(formatVersion: formatVersion, exportedAt: exportedAt, channels: legacyChannels)
            return
        }

        let snapshot = try ChannelRegistrySnapshot(from: decoder)
        self.init(channels: snapshot.channels)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(formatVersion, forKey: .formatVersion)
        try container.encode(exportedAt, forKey: .exportedAt)
        try container.encode(channels, forKey: .channels)
    }
}

enum ChannelRegistryTransferError: LocalizedError {
    case importFileMissing
    case invalidImportData

    var errorDescription: String? {
        switch self {
        case .importFileMissing:
            return "この端末内のバックアップファイルが見つかりません。先に書き出しを行ってください。"
        case .invalidImportData:
            return "バックアップファイルを読み込めませんでした。JSON の内容を確認してください。"
        }
    }
}

struct ChannelRegistryTransferResult: Hashable {
    let backend: ChannelRegistryTransferBackend
    let fileURL: URL
    let channelCount: Int
}

enum ChannelRegistryTransferBackend: String, CaseIterable, Hashable {
    case localDocuments

    var shortLabel: String {
        switch self {
        case .localDocuments:
            return "この端末内"
        }
    }

    var exportMenuTitle: String {
        switch self {
        case .localDocuments:
            return "バックアップを書き出し"
        }
    }

    var importMenuTitle: String {
        switch self {
        case .localDocuments:
            return "バックアップを読み込み"
        }
    }
}

enum ChannelRegistryTransferRuntime {
    static var preferredBackend: ChannelRegistryTransferBackend {
        return .localDocuments
    }

    static var availableBackends: [ChannelRegistryTransferBackend] {
        [.localDocuments]
    }
}

enum FeedBootstrapStore {
    static func load(channels: [String], fileManager: FileManager = .default) -> FeedBootstrapSnapshot {
        let url = FeedCachePaths.bootstrapURL(fileManager: fileManager)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = try? Data(contentsOf: url), let snapshot = try? decoder.decode(FeedBootstrapSnapshot.self, from: data) {
            return merged(snapshot: snapshot, channels: channels)
        }

        return merged(
            snapshot: FeedBootstrapSnapshot(
            progress: CacheProgress(
                totalChannels: channels.count,
                cachedChannels: 0,
                cachedVideos: 0,
                cachedThumbnails: 0,
                currentChannelID: nil,
                currentChannelNumber: nil,
                lastUpdatedAt: nil,
                isRunning: false,
                lastError: nil
            ),
            maintenanceItems: channels.map {
                ChannelMaintenanceItem(
                    id: $0,
                    channelID: $0,
                    channelTitle: nil,
                    lastSuccessAt: nil,
                    lastCheckedAt: nil,
                    latestPublishedAt: nil,
                    cachedVideoCount: 0,
                    lastError: nil,
                    freshness: .neverFetched
                )
            }
            ),
            channels: channels
        )
    }

    private static func merged(snapshot: FeedBootstrapSnapshot, channels: [String]) -> FeedBootstrapSnapshot {
        let existingItems = Dictionary(uniqueKeysWithValues: snapshot.maintenanceItems.map { ($0.channelID, $0) })
        let mergedItems = channels.map { channelID in
            existingItems[channelID] ?? ChannelMaintenanceItem(
                id: channelID,
                channelID: channelID,
                channelTitle: nil,
                lastSuccessAt: nil,
                lastCheckedAt: nil,
                latestPublishedAt: nil,
                cachedVideoCount: 0,
                lastError: nil,
                freshness: .neverFetched
            )
        }

        let currentChannelID = snapshot.progress.currentChannelID.flatMap { channels.contains($0) ? $0 : nil }
        let currentChannelNumber = currentChannelID.flatMap { channelID in
            channels.firstIndex(of: channelID).map { $0 + 1 }
        }

        return FeedBootstrapSnapshot(
            progress: CacheProgress(
                totalChannels: channels.count,
                cachedChannels: min(snapshot.progress.cachedChannels, channels.count),
                cachedVideos: snapshot.progress.cachedVideos,
                cachedThumbnails: snapshot.progress.cachedThumbnails,
                currentChannelID: currentChannelID,
                currentChannelNumber: currentChannelNumber,
                lastUpdatedAt: snapshot.progress.lastUpdatedAt,
                isRunning: snapshot.progress.isRunning,
                lastError: snapshot.progress.lastError
            ),
            maintenanceItems: mergedItems
        )
    }
}

enum ChannelRegistryStore {
    static func loadPersistedOrSeededChannelIDs(fileManager: FileManager = .default) -> [String] {
        ensureSeededFromLegacyCacheIfNeeded(fileManager: fileManager)
        return loadAllChannelIDs(fileManager: fileManager)
    }

    static func loadAllChannels(fileManager: FileManager = .default) -> [RegisteredChannel] {
        let channels = loadSnapshot(fileManager: fileManager).channels.map {
            RegisteredChannel(channelID: $0.channelID, addedAt: $0.addedAt)
        }
        return uniqueChannels(channels)
    }

    static func loadAllChannelIDs(fileManager: FileManager = .default) -> [String] {
        loadAllChannels(fileManager: fileManager).map(\.channelID)
    }

    static func registrationDate(for channelID: String, fileManager: FileManager = .default) -> Date? {
        loadAllChannels(fileManager: fileManager).first(where: { $0.channelID == channelID })?.addedAt
    }

    static func addChannelID(_ channelID: String, fileManager: FileManager = .default) throws -> Bool {
        let normalizedChannelID = channelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedChannelID.isEmpty else { return false }

        var snapshot = loadSnapshot(fileManager: fileManager)
        guard !snapshot.channels.contains(where: { $0.channelID == normalizedChannelID }) else {
            return false
        }

        snapshot.channels.append(
            RegisteredChannelRecord(channelID: normalizedChannelID, addedAt: .now)
        )
        snapshot.channels = uniqueRecords(snapshot.channels)
        try persist(snapshot: snapshot, fileManager: fileManager)
        return true
    }

    static func removeChannelID(_ channelID: String, fileManager: FileManager = .default) throws -> Bool {
        let normalizedChannelID = channelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedChannelID.isEmpty else { return false }

        var snapshot = loadSnapshot(fileManager: fileManager)
        let originalCount = snapshot.channels.count
        snapshot.channels.removeAll { $0.channelID == normalizedChannelID }
        guard snapshot.channels.count != originalCount else { return false }

        try persist(snapshot: snapshot, fileManager: fileManager)
        return true
    }

    static func loadChannelRecords(fileManager: FileManager = .default) -> [RegisteredChannelRecord] {
        loadAllChannels(fileManager: fileManager).map {
            RegisteredChannelRecord(channelID: $0.channelID, addedAt: $0.addedAt)
        }
    }

    static func replaceChannels(_ channels: [RegisteredChannelRecord], fileManager: FileManager = .default) throws {
        try persist(snapshot: ChannelRegistrySnapshot(channels: uniqueRecords(channels)), fileManager: fileManager)
    }

    private static func loadSnapshot(fileManager: FileManager) -> ChannelRegistrySnapshot {
        let url = FeedCachePaths.channelRegistryURL(fileManager: fileManager)
        guard
            let data = try? Data(contentsOf: url),
            let snapshot = try? JSONDecoder().decode(ChannelRegistrySnapshot.self, from: data)
        else {
            return ChannelRegistrySnapshot(channels: [])
        }

        return snapshot
    }

    private static func ensureSeededFromLegacyCacheIfNeeded(fileManager: FileManager) {
        let registryURL = FeedCachePaths.channelRegistryURL(fileManager: fileManager)
        guard !fileManager.fileExists(atPath: registryURL.path) else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var records: [RegisteredChannelRecord] = []

        if
            let data = try? Data(contentsOf: FeedCachePaths.bootstrapURL(fileManager: fileManager)),
            let bootstrap = try? decoder.decode(FeedBootstrapSnapshot.self, from: data)
        {
            records.append(contentsOf: bootstrap.maintenanceItems.map {
                RegisteredChannelRecord(channelID: $0.channelID, addedAt: nil)
            })
        }

        if
            let data = try? Data(contentsOf: FeedCachePaths.cacheURL(fileManager: fileManager)),
            let snapshot = try? decoder.decode(FeedCacheSnapshot.self, from: data)
        {
            records.append(contentsOf: snapshot.channels.map {
                RegisteredChannelRecord(channelID: $0.channelID, addedAt: nil)
            })
            records.append(contentsOf: snapshot.videos.map {
                RegisteredChannelRecord(channelID: $0.channelID, addedAt: nil)
            })
        }

        let seededRecords = uniqueRecords(records)
        guard !seededRecords.isEmpty else { return }
        try? persist(snapshot: ChannelRegistrySnapshot(channels: seededRecords), fileManager: fileManager)
    }

    private static func persist(snapshot: ChannelRegistrySnapshot, fileManager: FileManager) throws {
        let baseDirectory = FeedCachePaths.baseDirectory(fileManager: fileManager)
        try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: FeedCachePaths.channelRegistryURL(fileManager: fileManager), options: .atomic)
    }

    private static func uniqueChannels(_ channels: [RegisteredChannel]) -> [RegisteredChannel] {
        var seen = Set<String>()
        return channels.filter { seen.insert($0.channelID).inserted }
    }

    private static func uniqueRecords(_ channels: [RegisteredChannelRecord]) -> [RegisteredChannelRecord] {
        var seen = Set<String>()
        return channels.filter { seen.insert($0.channelID).inserted }
    }
}

enum ChannelRegistryTransferStore {
    static func export(fileManager: FileManager = .default, backend: ChannelRegistryTransferBackend = ChannelRegistryTransferRuntime.preferredBackend, containerURL: URL? = nil) throws -> ChannelRegistryTransferResult {
        let destinationURL = try transferDocumentURL(fileManager: fileManager, backend: backend, containerURL: containerURL)
        try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let document = ChannelRegistryTransferDocument(channels: ChannelRegistryStore.loadChannelRecords(fileManager: fileManager))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(document)
        try write(data, to: destinationURL, backend: backend)
        return ChannelRegistryTransferResult(backend: backend, fileURL: destinationURL, channelCount: document.channels.count)
    }

    static func `import`(fileManager: FileManager = .default, backend: ChannelRegistryTransferBackend = ChannelRegistryTransferRuntime.preferredBackend, containerURL: URL? = nil) throws -> ChannelRegistryTransferResult {
        let sourceURL = try transferDocumentURL(fileManager: fileManager, backend: backend, containerURL: containerURL)
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw ChannelRegistryTransferError.importFileMissing
        }

        let data = try read(from: sourceURL, backend: backend, fileManager: fileManager)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let document = try? decoder.decode(ChannelRegistryTransferDocument.self, from: data) else {
            throw ChannelRegistryTransferError.invalidImportData
        }

        try ChannelRegistryStore.replaceChannels(document.channels, fileManager: fileManager)
        return ChannelRegistryTransferResult(backend: backend, fileURL: sourceURL, channelCount: document.channels.count)
    }

    static func fixedPathDescription(fileManager: FileManager = .default, backend: ChannelRegistryTransferBackend = ChannelRegistryTransferRuntime.preferredBackend, containerURL: URL? = nil) -> String {
        (try? transferDocumentURL(fileManager: fileManager, backend: backend, containerURL: containerURL).path(percentEncoded: false))
        ?? fallbackPathDescription(for: backend)
    }

    private static func transferDocumentURL(fileManager: FileManager, backend: ChannelRegistryTransferBackend, containerURL: URL?) throws -> URL {
        switch backend {
        case .localDocuments:
            let rootURL: URL
            if let containerURL {
                rootURL = containerURL
            } else if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                rootURL = documentsURL
            } else {
                #if os(macOS)
                rootURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Documents", isDirectory: true)
                #else
                rootURL = fileManager.temporaryDirectory
                #endif
            }
            return rootURL
                .appendingPathComponent("HelloWorld", isDirectory: true)
                .appendingPathComponent("channel-registry.json")
        }
    }

    private static func write(_ data: Data, to url: URL, backend: ChannelRegistryTransferBackend) throws {
        try data.write(to: url, options: .atomic)
    }

    private static func read(from url: URL, backend: ChannelRegistryTransferBackend, fileManager: FileManager) throws -> Data {
        return try Data(contentsOf: url)
    }

    private static func fallbackPathDescription(for backend: ChannelRegistryTransferBackend) -> String {
        switch backend {
        case .localDocuments:
            return "~/Documents/HelloWorld/channel-registry.json"
        }
    }
}

enum VideoSortOrder: String, CaseIterable {
    case publishedDescending
}

struct VideoQuery: Hashable {
    var limit: Int = 50
    var channelID: String?
    var keyword: String?
    var sortOrder: VideoSortOrder = .publishedDescending
    var excludeShorts: Bool = true
}

nonisolated extension CachedVideo: Codable {}
nonisolated extension CachedChannelState: Codable {}
nonisolated extension FeedCacheSnapshot: Codable {}
nonisolated extension CacheProgress: Codable {}
nonisolated extension RefreshStageProgress: Codable {}
nonisolated extension CacheRefreshProgress: Codable {}
nonisolated extension ChannelFreshness: Codable {}
nonisolated extension ChannelMaintenanceItem: Codable {}
nonisolated extension FeedBootstrapSnapshot: Codable {}
nonisolated extension VideoSortOrder: Codable {}
nonisolated extension RemoteVideoSearchCacheEntry: Codable {}
