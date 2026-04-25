import XCTest
@testable import YoutubeFeeder

final class ChannelRefreshWallClockSchedulerTests: LoggedTestCase {
    func testMinuteZeroTriggersAllChannelsRefresh() {
        let scheduler = ChannelRefreshWallClockScheduler(calendar: calendar)
        let date = makeDate(hour: 12, minute: 0)

        XCTAssertEqual(scheduler.trigger(at: date), .allChannels)
    }

    func testMinuteZeroDoesNotTriggerRecentChannelsRefresh() {
        let scheduler = ChannelRefreshWallClockScheduler(calendar: calendar)
        let date = makeDate(hour: 12, minute: 0)

        XCTAssertNotEqual(scheduler.trigger(at: date), .recentChannels)
    }

    func testTenMinuteWallClockTicksTriggerRecentChannelsRefresh() {
        let scheduler = ChannelRefreshWallClockScheduler(calendar: calendar)

        for minute in [10, 20, 30, 40, 50] {
            XCTAssertEqual(
                scheduler.trigger(at: makeDate(hour: 12, minute: minute)),
                .recentChannels,
                "minute \(minute)"
            )
        }
    }

    func testNonWallClockTickDoesNotTriggerRefresh() {
        let scheduler = ChannelRefreshWallClockScheduler(calendar: calendar)

        XCTAssertNil(scheduler.trigger(at: makeDate(hour: 12, minute: 5)))
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeDate(hour: Int, minute: Int) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 4,
            day: 24,
            hour: hour,
            minute: minute,
            second: 0
        ).date!
    }
}
