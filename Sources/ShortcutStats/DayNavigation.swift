import Foundation

enum DayNavigation {
    static func moved(_ date: Date, by offset: Int, now: Date = Date(), calendar: Calendar = .current) -> Date {
        let day = calendar.startOfDay(for: date)
        let next = calendar.date(byAdding: .day, value: offset, to: day) ?? day
        return min(next, calendar.startOfDay(for: now))
    }
    static func canMoveForward(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: date) < calendar.startOfDay(for: now)
    }
}
