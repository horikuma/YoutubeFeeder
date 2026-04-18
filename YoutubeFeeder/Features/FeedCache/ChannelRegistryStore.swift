import Foundation

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
}

struct ChannelRegistryTransferDocument: Codable, Hashable {
    let formatVersion: Int
    let exportedAt: Date
    let channels: [RegisteredChannelRecord]

    init(formatVersion: Int = 2, exportedAt: Date = .now, channels: [RegisteredChannelRecord]) {
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.channels = channels
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
        .localDocuments
    }

    static var availableBackends: [ChannelRegistryTransferBackend] {
        [.localDocuments]
    }
}

enum ChannelRegistryStore {
    static func loadAllChannels(fileManager: FileManager = .default) -> [RegisteredChannel] {
        uniqueChannels(FeedCacheSQLiteDatabase.shared(fileManager: fileManager).loadRegisteredChannels())
    }

    static func loadAllChannelIDs(fileManager: FileManager = .default) -> [String] {
        loadAllChannels(fileManager: fileManager).map(\.channelID)
    }

    static func registrationDate(for channelID: String, fileManager: FileManager = .default) -> Date? {
        loadAllChannels(fileManager: fileManager).first(where: { $0.channelID == channelID })?.addedAt
    }

    static func addChannelID(
        _ channelID: String,
        fileManager: FileManager = .default,
        source: String = "unspecified"
    ) throws -> Bool {
        let normalizedChannelID = channelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedChannelID.isEmpty else { return false }
        let beforeChannels = loadAllChannelIDs(fileManager: fileManager)
        let didAdd = FeedCacheSQLiteDatabase.shared(fileManager: fileManager).addRegisteredChannel(normalizedChannelID, addedAt: .now)
        let afterChannels = loadAllChannelIDs(fileManager: fileManager)
        logMutation(
            "store_add_channel",
            source: source,
            beforeChannels: beforeChannels,
            afterChannels: afterChannels,
            metadata: [
                "channel_id": normalizedChannelID,
                "did_add": didAdd ? "true" : "false"
            ]
        )
        return didAdd
    }

    static func removeChannelID(
        _ channelID: String,
        fileManager: FileManager = .default,
        source: String = "unspecified"
    ) throws -> Bool {
        let normalizedChannelID = channelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedChannelID.isEmpty else { return false }
        let beforeChannels = loadAllChannelIDs(fileManager: fileManager)
        let didRemove = FeedCacheSQLiteDatabase.shared(fileManager: fileManager).removeRegisteredChannel(normalizedChannelID)
        let afterChannels = loadAllChannelIDs(fileManager: fileManager)
        logMutation(
            "store_remove_channel",
            source: source,
            beforeChannels: beforeChannels,
            afterChannels: afterChannels,
            metadata: [
                "channel_id": normalizedChannelID,
                "did_remove": didRemove ? "true" : "false"
            ]
        )
        return didRemove
    }

    static func loadChannelRecords(fileManager: FileManager = .default) -> [RegisteredChannelRecord] {
        loadAllChannels(fileManager: fileManager).map {
            RegisteredChannelRecord(channelID: $0.channelID, addedAt: $0.addedAt)
        }
    }

    static func replaceChannels(
        _ channels: [RegisteredChannelRecord],
        fileManager: FileManager = .default,
        source: String = "unspecified"
    ) throws {
        let beforeChannels = loadAllChannelIDs(fileManager: fileManager)
        let records = uniqueRecords(channels)
        FeedCacheSQLiteDatabase.shared(fileManager: fileManager).replaceRegisteredChannels(records)
        let afterChannels = loadAllChannelIDs(fileManager: fileManager)
        logMutation(
            "store_replace_channels",
            source: source,
            beforeChannels: beforeChannels,
            afterChannels: afterChannels,
            metadata: [
                "incoming_count": String(channels.count),
                "unique_incoming_count": String(records.count)
            ]
        )
    }

    static func reset(fileManager: FileManager = .default, source: String = "unspecified") throws -> Int {
        let beforeChannels = loadAllChannelIDs(fileManager: fileManager)
        let removedCount = FeedCacheSQLiteDatabase.shared(fileManager: fileManager).resetRegisteredChannels()
        let afterChannels = loadAllChannelIDs(fileManager: fileManager)
        logMutation(
            "store_reset_channels",
            source: source,
            beforeChannels: beforeChannels,
            afterChannels: afterChannels,
            metadata: ["removed_count": String(removedCount)]
        )
        return removedCount
    }

    private static func uniqueChannels(_ channels: [RegisteredChannel]) -> [RegisteredChannel] {
        var seen = Set<String>()
        return channels.filter { seen.insert($0.channelID).inserted }
    }

    private static func uniqueRecords(_ channels: [RegisteredChannelRecord]) -> [RegisteredChannelRecord] {
        var seen = Set<String>()
        return channels.filter { seen.insert($0.channelID).inserted }
    }

    private static func logMutation(
        _ event: String,
        source: String,
        beforeChannels: [String],
        afterChannels: [String],
        metadata: [String: String] = [:]
    ) {
        AppConsoleLogger.channelRegistry.notice(
            event,
            metadata: registryMetadata(
                source: source,
                beforeChannels: beforeChannels,
                afterChannels: afterChannels,
                metadata: metadata
            )
        )
    }

    private static func registryMetadata(
        source: String,
        beforeChannels: [String],
        afterChannels: [String],
        metadata: [String: String]
    ) -> [String: String] {
        var result = metadata
        result["source"] = source
        result["before_count"] = String(beforeChannels.count)
        result["after_count"] = String(afterChannels.count)
        result["delta"] = String(afterChannels.count - beforeChannels.count)
        result["before_fingerprint"] = AppConsoleLogger.channelIDsFingerprint(beforeChannels)
        result["after_fingerprint"] = AppConsoleLogger.channelIDsFingerprint(afterChannels)
        result["first_channel_before"] = beforeChannels.first ?? ""
        result["first_channel_after"] = afterChannels.first ?? ""
        result["last_channel_before"] = beforeChannels.last ?? ""
        result["last_channel_after"] = afterChannels.last ?? ""
        return result
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
        try write(data, to: destinationURL)
        return ChannelRegistryTransferResult(backend: backend, fileURL: destinationURL, channelCount: document.channels.count)
    }

    static func `import`(fileManager: FileManager = .default, backend: ChannelRegistryTransferBackend = ChannelRegistryTransferRuntime.preferredBackend, containerURL: URL? = nil) throws -> ChannelRegistryTransferResult {
        let sourceURL = try transferDocumentURL(fileManager: fileManager, backend: backend, containerURL: containerURL)
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw ChannelRegistryTransferError.importFileMissing
        }

        let data = try read(from: sourceURL, fileManager: fileManager)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let document = try? decoder.decode(ChannelRegistryTransferDocument.self, from: data) else {
            throw ChannelRegistryTransferError.invalidImportData
        }

        try ChannelRegistryStore.replaceChannels(document.channels, fileManager: fileManager, source: "transfer_import")
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
                .appendingPathComponent("YoutubeFeeder", isDirectory: true)
                .appendingPathComponent("channel-registry.json")
        }
    }

    private static func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }

    private static func read(from url: URL, fileManager: FileManager) throws -> Data {
        try Data(contentsOf: url)
    }

    private static func fallbackPathDescription(for backend: ChannelRegistryTransferBackend) -> String {
        switch backend {
        case .localDocuments:
            return "~/Documents/YoutubeFeeder/channel-registry.json"
        }
    }
}
