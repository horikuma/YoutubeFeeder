import XCTest
@testable import YoutubeFeeder

final class ChannelRefreshSchedulePolicyTests: LoggedTestCase {
    func testUsesTenMinuteIntervalForRecentChannels() {
        let now = Date(timeIntervalSince1970: 10_000)
        let recentState = CachedChannelState(
            channelID: "recent",
            channelTitle: nil,
            lastAttemptAt: nil,
            lastCheckedAt: nil,
            lastSuccessAt: nil,
            latestPublishedAt: now.addingTimeInterval(-9 * 24 * 60 * 60),
            cachedVideoCount: 0,
            lastError: nil,
            etag: nil,
            lastModified: nil
        )

        XCTAssertEqual(
            ChannelRefreshSchedulePolicy.refreshInterval(for: recentState, now: now),
            10 * 60
        )
    }

    func testUsesOneHourIntervalForOlderChannels() {
        let now = Date(timeIntervalSince1970: 10_000)
        let staleState = CachedChannelState(
            channelID: "stale",
            channelTitle: nil,
            lastAttemptAt: nil,
            lastCheckedAt: nil,
            lastSuccessAt: nil,
            latestPublishedAt: now.addingTimeInterval(-11 * 24 * 60 * 60),
            cachedVideoCount: 0,
            lastError: nil,
            etag: nil,
            lastModified: nil
        )

        XCTAssertEqual(
            ChannelRefreshSchedulePolicy.refreshInterval(for: staleState, now: now),
            60 * 60
        )
    }

    func testPrioritizesDueChannelsByLatestPublishedAtDescending() {
        let now = Date(timeIntervalSince1970: 10_000)
        let channels = ["A", "B", "C"]
        let states: [String: CachedChannelState] = [
            "A": makeState(id: "A", latestPublishedAt: now.addingTimeInterval(-11 * 24 * 60 * 60), lastCheckedAt: now.addingTimeInterval(-2 * 60 * 60)),
            "B": makeState(id: "B", latestPublishedAt: now.addingTimeInterval(-4 * 24 * 60 * 60), lastCheckedAt: now.addingTimeInterval(-2 * 60 * 60)),
            "C": makeState(id: "C", latestPublishedAt: now.addingTimeInterval(-1 * 24 * 60 * 60), lastCheckedAt: now.addingTimeInterval(-2 * 60 * 60))
        ]

        XCTAssertEqual(
            ChannelRefreshSchedulePolicy.prioritizedDueChannelIDs(channels: channels, states: states, now: now),
            ["C", "B", "A"]
        )
    }

    func testFreshSnapshotMarksAllChannelsAsNotDueUntilTheirIntervalsExpire() {
        let now = Date(timeIntervalSince1970: 10_000)
        let channels = ["recent", "older"]
        let states: [String: CachedChannelState] = [
            "recent": makeState(
                id: "recent",
                latestPublishedAt: now.addingTimeInterval(-1 * 24 * 60 * 60),
                lastCheckedAt: now.addingTimeInterval(-3 * 60)
            ),
            "older": makeState(
                id: "older",
                latestPublishedAt: now.addingTimeInterval(-11 * 24 * 60 * 60),
                lastCheckedAt: now.addingTimeInterval(-20 * 60)
            )
        ]

        XCTAssertEqual(
            ChannelRefreshSchedulePolicy.prioritizedDueChannelIDs(channels: channels, states: states, now: now),
            []
        )
    }

    func testMissingSnapshotStateIsDueImmediately() {
        let now = Date(timeIntervalSince1970: 10_000)

        XCTAssertEqual(
            ChannelRefreshSchedulePolicy.prioritizedDueChannelIDs(channels: ["missing"], states: [:], now: now),
            ["missing"]
        )
    }

    func testNextRefreshDelayUsesEarliestPendingChannel() {
        let now = Date(timeIntervalSince1970: 10_000)
        let channels = ["A", "B"]
        let states: [String: CachedChannelState] = [
            "A": makeState(id: "A", latestPublishedAt: now.addingTimeInterval(-2 * 24 * 60 * 60), lastCheckedAt: now.addingTimeInterval(-9 * 60)),
            "B": makeState(id: "B", latestPublishedAt: now.addingTimeInterval(-11 * 24 * 60 * 60), lastCheckedAt: now.addingTimeInterval(-50 * 60))
        ]

        XCTAssertEqual(
            ChannelRefreshSchedulePolicy.nextRefreshDelay(channels: channels, states: states, now: now),
            60
        )
    }

    func testNextRefreshDelayReturnsNilWhenThereAreNoChannels() {
        let now = Date(timeIntervalSince1970: 10_000)

        XCTAssertNil(
            ChannelRefreshSchedulePolicy.nextRefreshDelay(channels: [], states: [:], now: now)
        )
    }

    private func makeState(id: String, latestPublishedAt: Date, lastCheckedAt: Date) -> CachedChannelState {
        CachedChannelState(
            channelID: id,
            channelTitle: nil,
            lastAttemptAt: nil,
            lastCheckedAt: lastCheckedAt,
            lastSuccessAt: lastCheckedAt,
            latestPublishedAt: latestPublishedAt,
            cachedVideoCount: 0,
            lastError: nil,
            etag: nil,
            lastModified: nil
        )
    }
}
