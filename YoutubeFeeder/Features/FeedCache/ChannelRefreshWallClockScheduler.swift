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
        let triggerMinutes = ChannelRefreshWallClockPolicy.triggerMinutes.sorted()

        for minute in triggerMinutes {
            guard let candidate = dateInSameHour(as: date, minute: minute) else { continue }
            if candidate > date {
                return candidate
            }
        }

        let nextHourBase = calendar.date(byAdding: .hour, value: 1, to: date) ?? date.addingTimeInterval(60 * 60)
        if let candidate = dateInSameHour(as: nextHourBase, minute: triggerMinutes[0]), candidate > date {
            return candidate
        }
        return nextHourBase
    }

    private func dateInSameHour(as date: Date, minute: Int) -> Date? {
        var components = calendar.dateComponents([.era, .year, .month, .day, .hour], from: date)
        components.minute = minute
        components.second = 0
        components.nanosecond = 0
        return calendar.date(from: components)
    }
}
