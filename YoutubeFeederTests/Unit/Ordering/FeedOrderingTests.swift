import XCTest
@testable import YoutubeFeeder

final class FeedOrderingTests: LoggedTestCase {
    func testPrioritizesLatestPublishedThenOldestChecked() {
        let now = Date(timeIntervalSince1970: 1_000)
        let channels = ["A", "B", "C"]
        let states: [String: CachedChannelState] = [
            "A": CachedChannelState(
                channelID: "A",
                channelTitle: nil,
                lastAttemptAt: nil,
                lastCheckedAt: now.addingTimeInterval(-50),
                lastSuccessAt: nil,
                latestPublishedAt: now.addingTimeInterval(-100),
                cachedVideoCount: 0,
                lastError: nil,
                etag: nil,
                lastModified: nil
            ),
            "B": CachedChannelState(
                channelID: "B",
                channelTitle: nil,
                lastAttemptAt: nil,
                lastCheckedAt: now.addingTimeInterval(-500),
                lastSuccessAt: nil,
                latestPublishedAt: now.addingTimeInterval(-100),
                cachedVideoCount: 0,
                lastError: nil,
                etag: nil,
                lastModified: nil
            ),
            "C": CachedChannelState(
                channelID: "C",
                channelTitle: nil,
                lastAttemptAt: nil,
                lastCheckedAt: now.addingTimeInterval(-10),
                lastSuccessAt: nil,
                latestPublishedAt: now.addingTimeInterval(-10),
                cachedVideoCount: 0,
                lastError: nil,
                etag: nil,
                lastModified: nil
            )
        ]

        XCTAssertEqual(
            FeedOrdering.prioritizedChannelIDs(channels: channels, states: states),
            ["C", "B", "A"]
        )
    }

    func testFreshnessClassifiesAge() {
        let now = Date(timeIntervalSince1970: 10_000)

        XCTAssertEqual(
            FeedOrdering.freshness(lastSuccessAt: now.addingTimeInterval(-30), now: now, freshnessInterval: 60),
            .fresh
        )
        XCTAssertEqual(
            FeedOrdering.freshness(lastSuccessAt: now.addingTimeInterval(-300), now: now, freshnessInterval: 60),
            .stale
        )
        XCTAssertEqual(
            FeedOrdering.freshness(lastSuccessAt: nil, now: now, freshnessInterval: 60),
            .neverFetched
        )
    }

    func testPrioritizesRecentlySuccessfulChannelsWhenLatestPublishedMatches() {
        let now = Date(timeIntervalSince1970: 5_000)
        let channels = ["A", "B"]
        let states: [String: CachedChannelState] = [
            "A": CachedChannelState(
                channelID: "A",
                channelTitle: nil,
                lastAttemptAt: nil,
                lastCheckedAt: now.addingTimeInterval(-500),
                lastSuccessAt: now.addingTimeInterval(-50),
                latestPublishedAt: now.addingTimeInterval(-100),
                cachedVideoCount: 0,
                lastError: nil,
                etag: nil,
                lastModified: nil
            ),
            "B": CachedChannelState(
                channelID: "B",
                channelTitle: nil,
                lastAttemptAt: nil,
                lastCheckedAt: now.addingTimeInterval(-50),
                lastSuccessAt: now.addingTimeInterval(-500),
                latestPublishedAt: now.addingTimeInterval(-100),
                cachedVideoCount: 0,
                lastError: nil,
                etag: nil,
                lastModified: nil
            )
        ]

        XCTAssertEqual(
            FeedOrdering.prioritizedChannelIDs(channels: channels, states: states),
            ["A", "B"]
        )
    }

    func testSortBrowseItemsByRegistrationDateDescending() {
        let older = Date(timeIntervalSince1970: 1_000)
        let newer = Date(timeIntervalSince1970: 2_000)
        let items = [
            ChannelBrowseItem(
                id: "A",
                channelID: "A",
                channelTitle: "A",
                latestPublishedAt: nil,
                registeredAt: older,
                latestVideo: nil,
                cachedVideoCount: 0
            ),
            ChannelBrowseItem(
                id: "B",
                channelID: "B",
                channelTitle: "B",
                latestPublishedAt: nil,
                registeredAt: newer,
                latestVideo: nil,
                cachedVideoCount: 0
            ),
            ChannelBrowseItem(
                id: "C",
                channelID: "C",
                channelTitle: "C",
                latestPublishedAt: nil,
                registeredAt: nil,
                latestVideo: nil,
                cachedVideoCount: 0
            )
        ]

        XCTAssertEqual(
            FeedOrdering.sortBrowseItems(
                items,
                by: ChannelBrowseSortDescriptor(metric: .registrationDate, direction: .descending)
            ).map(\.channelID),
            ["B", "A", "C"]
        )
    }

    func testSortBrowseItemsByRegistrationDateAscending() {
        let older = Date(timeIntervalSince1970: 1_000)
        let newer = Date(timeIntervalSince1970: 2_000)
        let items = [
            ChannelBrowseItem(
                id: "A",
                channelID: "A",
                channelTitle: "A",
                latestPublishedAt: nil,
                registeredAt: older,
                latestVideo: nil,
                cachedVideoCount: 0
            ),
            ChannelBrowseItem(
                id: "B",
                channelID: "B",
                channelTitle: "B",
                latestPublishedAt: nil,
                registeredAt: newer,
                latestVideo: nil,
                cachedVideoCount: 0
            )
        ]

        XCTAssertEqual(
            FeedOrdering.sortBrowseItems(
                items,
                by: ChannelBrowseSortDescriptor(metric: .registrationDate, direction: .ascending)
            ).map(\.channelID),
            ["A", "B"]
        )
    }
}
