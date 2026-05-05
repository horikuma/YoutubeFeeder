import Foundation

struct RefreshCycleStartRequest {
    let startedEvent: String
    let evaluatedEvent: String
    let evaluationIsDebug: Bool
    let refreshSource: String
    let targetChannelsCount: Int
    let snapshotChannelCount: Int
    let channelCount: Int
    let dueChannelsCount: Int
    let freshnessBypassed: String?
    let forceNetworkFetch: String?
    let snapshotDependency: String?
    let snapshotDependencyDetail: String?
    let channelFingerprint: String?
    let snapshotFingerprint: String?
}

struct RefreshCycleFinishRequest {
    let event: String
    let startedAt: Date
    let cycleResult: FeedRefreshCycleResult
    let channelCount: Int
    let targetChannelsCount: Int
    let snapshotChannelCount: Int
    let refreshSource: String
    let dueChannelsCount: Int?
}
