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

    static func reset(fileManager: FileManager = .default) throws -> Int {
        let existingCount = loadAllChannels(fileManager: fileManager).count
        let registryURL = FeedCachePaths.channelRegistryURL(fileManager: fileManager)
        if fileManager.fileExists(atPath: registryURL.path) {
            try fileManager.removeItem(at: registryURL)
        }
        return existingCount
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

    private static func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }

    private static func read(from url: URL, fileManager: FileManager) throws -> Data {
        try Data(contentsOf: url)
    }

    private static func fallbackPathDescription(for backend: ChannelRegistryTransferBackend) -> String {
        switch backend {
        case .localDocuments:
            return "~/Documents/HelloWorld/channel-registry.json"
        }
    }
}
