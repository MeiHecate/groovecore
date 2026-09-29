import Foundation

public enum SlotBuilder {
    /// Reminder times of a day: start, start + interval, … up to end included. Empty on rest days.
    public static func slots(on day: LocalDay, settings: GrooveSettings, calendar: Calendar) -> [Date] {
        guard !settings.isRestDay(day, calendar: calendar),
              settings.windowStartMinutes <= settings.windowEndMinutes else { return [] }
        return stride(from: settings.windowStartMinutes, through: settings.windowEndMinutes, by: settings.effectiveInterval)
            .map { day.date(minutesFromMidnight: $0, calendar: calendar) }
    }
}
