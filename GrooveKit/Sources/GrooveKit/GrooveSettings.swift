import Foundation

public struct GrooveSettings: Codable, Equatable, Sendable {
    public var windowStartMinutes: Int
    public var windowEndMinutes: Int
    public var intervalMinutes: Int
    public var maxBlockSize: Int
    /// Calendar weekdays, 1 = Sunday … 7 = Saturday.
    public var restWeekdays: Set<Int>
    public var defaultWorkPercent: Int
    public var soundEnabled: Bool

    public static let minimumInterval = 20

    public init(
        windowStartMinutes: Int = 8 * 60,
        windowEndMinutes: Int = 20 * 60,
        intervalMinutes: Int = 45,
        maxBlockSize: Int = 5,
        restWeekdays: Set<Int> = [],
        defaultWorkPercent: Int = 50,
        soundEnabled: Bool = true
    ) {
        self.windowStartMinutes = windowStartMinutes
        self.windowEndMinutes = windowEndMinutes
        self.intervalMinutes = intervalMinutes
        self.maxBlockSize = maxBlockSize
        self.restWeekdays = restWeekdays
        self.defaultWorkPercent = defaultWorkPercent
        self.soundEnabled = soundEnabled
    }

    public var effectiveInterval: Int { max(Self.minimumInterval, intervalMinutes) }

    public func isRestDay(_ day: LocalDay, calendar: Calendar) -> Bool {
        restWeekdays.contains(day.weekday(calendar: calendar))
    }

    private static let lastMinute = 23 * 60 + 59

    public mutating func setWindowStart(_ minutes: Int) {
        windowStartMinutes = min(max(0, minutes), Self.lastMinute - effectiveInterval)
        if windowEndMinutes <= windowStartMinutes {
            windowEndMinutes = windowStartMinutes + effectiveInterval
        }
    }

    public mutating func setWindowEnd(_ minutes: Int) {
        windowEndMinutes = min(max(effectiveInterval, minutes), Self.lastMinute)
        if windowStartMinutes >= windowEndMinutes {
            windowStartMinutes = windowEndMinutes - effectiveInterval
        }
    }
}
