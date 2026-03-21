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

struct ChannelBrowseTipsSummary: Hashable {
    let countText: String
    let sortText: String
    let primaryHint: String
    let secondaryHint: String

    static func build(items: [ChannelBrowseItem], sortDescriptor: ChannelBrowseSortDescriptor) -> Self {
        Self(
            countText: "\(items.count)件",
            sortText: sortDescriptor.shortLabel,
            primaryHint: "タップで動画一覧",
            secondaryHint: "長押しで削除"
        )
    }
}

enum RemoteSearchChipMode: String, Hashable {
    case hidden
    case summary
    case refreshing
}

struct RemoteSearchPresentationState: Hashable {
    var visibleCount: Int
    var chipMode: RemoteSearchChipMode
    var splitContext: ChannelVideosRouteContext?

    var isChipVisible: Bool {
        chipMode != .hidden
    }

    var isRefreshingChip: Bool {
        chipMode == .refreshing
    }

    static func build(
        result: VideoSearchResult,
        usesSplitChannelBrowser: Bool,
        previousSplitContext: ChannelVideosRouteContext?
    ) -> Self {
        RemoteSearchPresentationState(
            visibleCount: min(20, max(result.videos.count, 20)),
            chipMode: result.fetchedAt != nil ? .summary : .hidden,
            splitContext: defaultSplitContext(
                result: result,
                usesSplitChannelBrowser: usesSplitChannelBrowser,
                previousSplitContext: previousSplitContext
            )
        )
    }

    mutating func dismissChip() {
        chipMode = .hidden
    }

    mutating func beginRefresh() {
        chipMode = .refreshing
    }

    mutating func loadMoreIfNeeded(totalVideoCount: Int) {
        guard visibleCount < totalVideoCount else { return }
        visibleCount = min(visibleCount + 20, totalVideoCount)
    }

    private static func defaultSplitContext(
        result: VideoSearchResult,
        usesSplitChannelBrowser: Bool,
        previousSplitContext: ChannelVideosRouteContext?
    ) -> ChannelVideosRouteContext? {
        guard usesSplitChannelBrowser else { return nil }
        if let previousSplitContext,
           result.videos.contains(where: { $0.channelID == previousSplitContext.channelID }) {
            return previousSplitContext
        }
        guard let firstVideo = result.videos.first else { return nil }
        return ChannelVideosRouteContext(
            channelID: firstVideo.channelID,
            preferredChannelTitle: normalizedChannelTitle(for: firstVideo),
            selectedVideoID: firstVideo.id,
            prefersAutomaticRefresh: true
        )
    }

    private static func normalizedChannelTitle(for video: CachedVideo) -> String? {
        video.channelTitle.isEmpty ? nil : video.channelTitle
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

enum ChannelVideosAutoRefreshPolicy {
    static func shouldRefresh(cachedChannelVideos: [CachedVideo], selectedVideoID: String?) -> Bool {
        if cachedChannelVideos.isEmpty {
            return true
        }

        guard let selectedVideoID, !selectedVideoID.isEmpty else {
            return false
        }

        return !cachedChannelVideos.contains { $0.id == selectedVideoID }
    }
}

enum RemoteSearchErrorPolicy {
    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            return true
        }

        return nsError.localizedDescription
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == "cancelled"
    }

    static func userMessage(for error: Error) -> String? {
        guard !isCancellation(error) else { return nil }
        return error.localizedDescription
    }

    static func diagnosticReason(for error: Error) -> String {
        if error is CancellationError {
            return "task_cancellation"
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            return "urlsession_cancelled"
        }

        return String(describing: type(of: error))
    }
}
