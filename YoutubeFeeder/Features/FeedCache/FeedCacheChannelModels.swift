import Foundation

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

struct LocalStateResetFeedback: Hashable {
    let removedChannelCount: Int
    let removedVideoCount: Int
    let removedThumbnailCount: Int
    let removedSearchCacheCount: Int

    var title: String {
        "全設定をリセットしました"
    }

    var detail: String {
        "チャンネル \(removedChannelCount) 件、動画 \(removedVideoCount) 件、サムネイル \(removedThumbnailCount) 件、検索履歴 \(removedSearchCacheCount) 件を削除"
    }
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

nonisolated extension ChannelFreshness: Codable {}
nonisolated extension ChannelMaintenanceItem: Codable {}
