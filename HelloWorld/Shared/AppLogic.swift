import CoreGraphics
import Foundation

enum BackSwipePolicy {
    static let activeRegionWidth: CGFloat = 140
    static let minimumHorizontalTravel: CGFloat = 90

    static func shouldNavigateBack(startX: CGFloat, translation: CGSize) -> Bool {
        guard startX <= activeRegionWidth else { return false }
        guard translation.width > minimumHorizontalTravel else { return false }
        return abs(translation.width) > abs(translation.height)
    }
}

enum VideoOpenPolicy {
    static let minimumPressDuration: TimeInterval = 1.0
    static let maximumMovement: CGFloat = 18
}

enum FeedOrdering {
    static func prioritizedChannelIDs(channels: [String], states: [String: CachedChannelState]) -> [String] {
        channels.sorted { lhs, rhs in
            let lhsLatest = states[lhs]?.latestPublishedAt ?? .distantPast
            let rhsLatest = states[rhs]?.latestPublishedAt ?? .distantPast

            if lhsLatest != rhsLatest {
                return lhsLatest > rhsLatest
            }

            let lhsSuccess = states[lhs]?.lastSuccessAt ?? .distantPast
            let rhsSuccess = states[rhs]?.lastSuccessAt ?? .distantPast
            if lhsSuccess != rhsSuccess {
                return lhsSuccess > rhsSuccess
            }

            let lhsChecked = states[lhs]?.lastCheckedAt ?? .distantPast
            let rhsChecked = states[rhs]?.lastCheckedAt ?? .distantPast
            return lhsChecked < rhsChecked
        }
    }

    static func freshness(lastSuccessAt: Date?, now: Date = .now, freshnessInterval: TimeInterval) -> ChannelFreshness {
        guard let lastSuccessAt else {
            return .neverFetched
        }

        let age = now.timeIntervalSince(lastSuccessAt)
        return age <= freshnessInterval ? .fresh : .stale
    }
}
