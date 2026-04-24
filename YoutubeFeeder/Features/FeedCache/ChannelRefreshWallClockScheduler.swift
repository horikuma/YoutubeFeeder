import Foundation

struct ChannelRefreshWallClockScheduler {
    var calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func trigger(at date: Date) -> ChannelRefreshTrigger? {
        ChannelRefreshWallClockPolicy.trigger(at: date, calendar: calendar)
    }

    func nextTriggerDate(after date: Date) -> Date {
        let currentMinute = calendar.component(.minute, from: date)
        let currentSecond = calendar.component(.second, from: date)
        let currentNanosecond = calendar.component(.nanosecond, from: date)
        let triggerMinutes = ChannelRefreshWallClockPolicy.triggerMinutes.sorted()

        for minute in triggerMinutes where minute >= currentMinute {
            guard let candidate = dateInSameHour(as: date, minute: minute) else { continue }
            if minute > currentMinute || currentSecond > 0 || currentNanosecond > 0 {
                return candidate
            }
        }

        let nextHour = calendar.date(byAdding: .hour, value: 1, to: date) ?? date.addingTimeInterval(60 * 60)
        return dateInSameHour(as: nextHour, minute: triggerMinutes[0]) ?? nextHour
    }

    private func dateInSameHour(as date: Date, minute: Int) -> Date? {
        var components = calendar.dateComponents([.era, .year, .month, .day, .hour], from: date)
        components.minute = minute
        components.second = 0
        components.nanosecond = 0
        return calendar.date(from: components)
    }
}
