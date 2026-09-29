import Foundation
import GrooveKit

enum MonthGrid {
    /// Cells of a month, Monday first; nil for the blanks before the 1st.
    static func cells(year: Int, month: Int, calendar: Calendar) -> [LocalDay?] {
        let first = LocalDay(year: year, month: month, day: 1)
        let count = calendar.range(of: .day, in: .month, for: first.date(minutesFromMidnight: 12 * 60, calendar: calendar))!.count
        let blanks = (first.weekday(calendar: calendar) + 5) % 7
        return Array(repeating: nil, count: blanks) + (1...count).map { LocalDay(year: year, month: month, day: $0) }
    }
}
