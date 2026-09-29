import Foundation

/// A calendar day in the user's local time zone. Never derived from UTC.
public struct LocalDay: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(_ date: Date, calendar: Calendar) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year!, month: c.month!, day: c.day!)
    }

    public init?(key: String) {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    public var key: String { String(format: "%04d-%02d-%02d", year, month, day) }
    public var description: String { key }

    public func date(minutesFromMidnight minutes: Int = 0, calendar: Calendar) -> Date {
        let c = DateComponents(year: year, month: month, day: day, hour: minutes / 60, minute: minutes % 60)
        return calendar.date(from: c)!
    }

    public func adding(days: Int, calendar: Calendar) -> LocalDay {
        let noon = date(minutesFromMidnight: 12 * 60, calendar: calendar)
        return LocalDay(calendar.date(byAdding: .day, value: days, to: noon)!, calendar: calendar)
    }

    /// 1 = Sunday … 7 = Saturday (Calendar convention).
    public func weekday(calendar: Calendar) -> Int {
        calendar.component(.weekday, from: date(minutesFromMidnight: 12 * 60, calendar: calendar))
    }

    public static func < (a: LocalDay, b: LocalDay) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }
}
