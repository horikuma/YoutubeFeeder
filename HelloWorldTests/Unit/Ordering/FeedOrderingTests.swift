import XCTest
@testable import HelloWorld

final class FeedOrderingTests: XCTestCase {
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
            ),
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
            ),
        ]

        XCTAssertEqual(
            FeedOrdering.prioritizedChannelIDs(channels: channels, states: states),
            ["A", "B"]
        )
    }
}
