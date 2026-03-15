import CoreGraphics
import Foundation

enum BackSwipePolicy {
    static let activeRegionWidth: CGFloat = 24
    static let minimumHorizontalTravel: CGFloat = 110

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

enum SortDirection: String, CaseIterable, Hashable {
    case descending
    case ascending

    var symbol: String {
        switch self {
        case .descending: return "↓"
        case .ascending: return "↑"
        }
    }
}

enum ChannelBrowseSortMetric: String, CaseIterable, Hashable, Identifiable {
    case latestPublishedAt
    case registrationDate

    var id: Self { self }

    var label: String {
        switch self {
        case .latestPublishedAt:
            return "動画投稿日時"
        case .registrationDate:
            return "チャンネル登録日時"
        }
    }
}

struct ChannelBrowseSortDescriptor: Hashable {
    let metric: ChannelBrowseSortMetric
    let direction: SortDirection

    nonisolated static let `default` = ChannelBrowseSortDescriptor(metric: .latestPublishedAt, direction: .descending)

    var shortLabel: String {
        "\(metric.label) \(direction.symbol)"
    }

    var listSubtitle: String {
        switch (metric, direction) {
        case (.latestPublishedAt, .descending):
            return "動画投稿日時が新しい順"
        case (.latestPublishedAt, .ascending):
            return "動画投稿日時が古い順"
        case (.registrationDate, .descending):
            return "チャンネル登録日時が新しい順"
        case (.registrationDate, .ascending):
            return "チャンネル登録日時が古い順"
        }
    }
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

    static func sortBrowseItems(_ items: [ChannelBrowseItem], by descriptor: ChannelBrowseSortDescriptor) -> [ChannelBrowseItem] {
        items.sorted { lhs, rhs in
            let comparison = compareDates(
                lhs: value(for: lhs, metric: descriptor.metric),
                rhs: value(for: rhs, metric: descriptor.metric),
                direction: descriptor.direction
            )
            if comparison != .orderedSame {
                return comparison == .orderedAscending
            }

            let publishedComparison = compareDates(
                lhs: lhs.latestPublishedAt,
                rhs: rhs.latestPublishedAt,
                direction: .descending
            )
            if publishedComparison != .orderedSame {
                return publishedComparison == .orderedAscending
            }

            return lhs.channelTitle.localizedCaseInsensitiveCompare(rhs.channelTitle) == .orderedAscending
        }
    }

    private static func value(for item: ChannelBrowseItem, metric: ChannelBrowseSortMetric) -> Date? {
        switch metric {
        case .latestPublishedAt:
            return item.latestPublishedAt
        case .registrationDate:
            return item.registeredAt
        }
    }

    private static func compareDates(lhs: Date?, rhs: Date?, direction: SortDirection) -> ComparisonResult {
        switch (lhs, rhs) {
        case let (left?, right?):
            if left == right { return .orderedSame }
            switch direction {
            case .descending:
                return left > right ? .orderedAscending : .orderedDescending
            case .ascending:
                return left < right ? .orderedAscending : .orderedDescending
            }
        case (nil, nil):
            return .orderedSame
        case (_?, nil):
            return .orderedAscending
        case (nil, _?):
            return .orderedDescending
        }
    }
}
