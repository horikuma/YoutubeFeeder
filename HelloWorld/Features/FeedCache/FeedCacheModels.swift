import Foundation

enum FeedCachePaths {
    static func baseDirectory(fileManager: FileManager = .default) -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return appSupport.appendingPathComponent("FeedCache", isDirectory: true)
    }

    static func thumbnailsDirectory(fileManager: FileManager = .default) -> URL {
        baseDirectory(fileManager: fileManager).appendingPathComponent("thumbnails", isDirectory: true)
    }

    static func thumbnailURL(filename: String, fileManager: FileManager = .default) -> URL {
        thumbnailsDirectory(fileManager: fileManager).appendingPathComponent(filename)
    }

    static func bootstrapURL(fileManager: FileManager = .default) -> URL {
        baseDirectory(fileManager: fileManager).appendingPathComponent("maintenance-bootstrap.json")
    }

    static func cacheURL(fileManager: FileManager = .default) -> URL {
        baseDirectory(fileManager: fileManager).appendingPathComponent("cache.json")
    }

    static func channelRegistryURL(fileManager: FileManager = .default) -> URL {
        baseDirectory(fileManager: fileManager).appendingPathComponent("channel-registry.json")
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

enum ChannelRegistryTransferAction: Hashable {
    case export
    case `import`
}

struct ChannelRegistryTransferFeedback: Hashable {
    let action: ChannelRegistryTransferAction
    let channelCount: Int
    let path: String
    let refreshMessage: String?

    var title: String {
        switch action {
        case .export:
            return "iCloudへ書き出しました"
        case .import:
            return "iCloudから読み込みました"
        }
    }

    var detail: String {
        switch action {
        case .export:
            return "追加チャンネル \(channelCount) 件を保存"
        case .import:
            return "追加チャンネル \(channelCount) 件を反映"
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
    var customChannels: [RegisteredChannelRecord]

    init(customChannels: [RegisteredChannelRecord]) {
        self.customChannels = customChannels
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let snapshot = try? container.decode(LegacySnapshot.self) {
            customChannels = snapshot.customChannelIDs.map {
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
        let customChannels: [RegisteredChannelRecord]

        init(snapshot: ChannelRegistrySnapshot) {
            customChannels = snapshot.customChannels
        }

        var snapshot: ChannelRegistrySnapshot {
            ChannelRegistrySnapshot(customChannels: customChannels)
        }
    }
}

struct ChannelRegistryTransferDocument: Codable, Hashable {
    let formatVersion: Int
    let exportedAt: Date
    let customChannels: [RegisteredChannelRecord]

    init(formatVersion: Int = 1, exportedAt: Date = .now, customChannels: [RegisteredChannelRecord]) {
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.customChannels = customChannels
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let formatVersion = try? container.decode(Int.self, forKey: .formatVersion),
           let exportedAt = try? container.decode(Date.self, forKey: .exportedAt),
           let customChannels = try? container.decode([RegisteredChannelRecord].self, forKey: .customChannels) {
            self.init(formatVersion: formatVersion, exportedAt: exportedAt, customChannels: customChannels)
            return
        }

        let snapshot = try ChannelRegistrySnapshot(from: decoder)
        self.init(customChannels: snapshot.customChannels)
    }
}

enum ChannelRegistryTransferError: LocalizedError {
    case iCloudUnavailable
    case importFileMissing
    case invalidImportData

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return "iCloud Drive を利用できません。iCloud Drive の設定を確認してください。"
        case .importFileMissing:
            return "iCloud 上の引き継ぎファイルが見つかりません。先に書き出しを行ってください。"
        case .invalidImportData:
            return "引き継ぎファイルを読み込めませんでした。JSON の内容を確認してください。"
        }
    }
}

struct ChannelRegistryTransferResult: Hashable {
    let fileURL: URL
    let customChannelCount: Int
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
    static func loadAllChannels(bundle: Bundle = .main, fileManager: FileManager = .default) -> [RegisteredChannel] {
        let bundledChannels = ChannelResource.loadChannelIDs(bundle: bundle).map {
            RegisteredChannel(channelID: $0, addedAt: nil)
        }
        let customChannels = loadSnapshot(fileManager: fileManager).customChannels.map {
            RegisteredChannel(channelID: $0.channelID, addedAt: $0.addedAt)
        }
        return uniqueChannels(bundledChannels + customChannels)
    }

    static func loadAllChannelIDs(bundle: Bundle = .main, fileManager: FileManager = .default) -> [String] {
        loadAllChannels(bundle: bundle, fileManager: fileManager).map(\.channelID)
    }

    static func registrationDate(for channelID: String, bundle: Bundle = .main, fileManager: FileManager = .default) -> Date? {
        loadAllChannels(bundle: bundle, fileManager: fileManager).first(where: { $0.channelID == channelID })?.addedAt
    }

    static func addChannelID(_ channelID: String, fileManager: FileManager = .default) throws -> Bool {
        let normalizedChannelID = channelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedChannelID.isEmpty else { return false }

        let bundledChannelIDs = Set(ChannelResource.loadChannelIDs())
        if bundledChannelIDs.contains(normalizedChannelID) {
            return false
        }

        var snapshot = loadSnapshot(fileManager: fileManager)
        guard !snapshot.customChannels.contains(where: { $0.channelID == normalizedChannelID }) else {
            return false
        }

        snapshot.customChannels.append(
            RegisteredChannelRecord(channelID: normalizedChannelID, addedAt: .now)
        )
        snapshot.customChannels = uniqueRecords(snapshot.customChannels)
        try persist(snapshot: snapshot, fileManager: fileManager)
        return true
    }

    static func loadCustomChannelRecords(fileManager: FileManager = .default) -> [RegisteredChannelRecord] {
        loadSnapshot(fileManager: fileManager).customChannels
    }

    static func replaceCustomChannels(_ customChannels: [RegisteredChannelRecord], fileManager: FileManager = .default) throws {
        try persist(snapshot: ChannelRegistrySnapshot(customChannels: uniqueRecords(customChannels)), fileManager: fileManager)
    }

    private static func loadSnapshot(fileManager: FileManager) -> ChannelRegistrySnapshot {
        let url = FeedCachePaths.channelRegistryURL(fileManager: fileManager)
        guard
            let data = try? Data(contentsOf: url),
            let snapshot = try? JSONDecoder().decode(ChannelRegistrySnapshot.self, from: data)
        else {
            return ChannelRegistrySnapshot(customChannels: [])
        }

        return snapshot
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
    static func exportToICloud(fileManager: FileManager = .default, containerURL: URL? = nil) throws -> ChannelRegistryTransferResult {
        let destinationURL = try iCloudDocumentURL(fileManager: fileManager, containerURL: containerURL)
        try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let document = ChannelRegistryTransferDocument(customChannels: ChannelRegistryStore.loadCustomChannelRecords(fileManager: fileManager))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(document)
        try data.write(to: destinationURL, options: .atomic)
        return ChannelRegistryTransferResult(fileURL: destinationURL, customChannelCount: document.customChannels.count)
    }

    static func importFromICloud(fileManager: FileManager = .default, containerURL: URL? = nil) throws -> ChannelRegistryTransferResult {
        let sourceURL = try iCloudDocumentURL(fileManager: fileManager, containerURL: containerURL)
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw ChannelRegistryTransferError.importFileMissing
        }

        let data = try Data(contentsOf: sourceURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let document = try? decoder.decode(ChannelRegistryTransferDocument.self, from: data) else {
            throw ChannelRegistryTransferError.invalidImportData
        }

        try ChannelRegistryStore.replaceCustomChannels(document.customChannels, fileManager: fileManager)
        return ChannelRegistryTransferResult(fileURL: sourceURL, customChannelCount: document.customChannels.count)
    }

    static func fixedPathDescription(fileManager: FileManager = .default, containerURL: URL? = nil) -> String {
        (try? iCloudDocumentURL(fileManager: fileManager, containerURL: containerURL).path(percentEncoded: false))
        ?? "iCloud Drive/Documents/channel-registry.json"
    }

    private static func iCloudDocumentURL(fileManager: FileManager, containerURL: URL?) throws -> URL {
        let rootURL: URL?
        if let containerURL {
            rootURL = containerURL
        } else {
            rootURL = fileManager.url(forUbiquityContainerIdentifier: nil)
        }

        guard let rootURL else {
            throw ChannelRegistryTransferError.iCloudUnavailable
        }

        return rootURL
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("channel-registry.json")
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
