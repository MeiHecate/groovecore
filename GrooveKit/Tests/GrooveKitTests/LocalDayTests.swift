import Foundation
import Testing
@testable import GrooveKit

@Suite struct LocalDayTests {
    @Test func lateEveningStaysOnSameDay() {
        #expect(LocalDay(parisDate(2026, 9, 26, 23, 30), calendar: .paris) == day(2026, 9, 26))
    }

    @Test func justAfterMidnightIsNextDayEvenThoughUTCIsStillPreviousDay() {
        // 00:30 Paris = 22:30 UTC the day before: the bug of the Hiit app
        #expect(LocalDay(parisDate(2026, 9, 27, 0, 30), calendar: .paris) == day(2026, 9, 27))
    }

    @Test func keyRoundTrip() {
        #expect(day(2026, 9, 6).key == "2026-09-06")
        #expect(LocalDay(key: "2026-09-06") == day(2026, 9, 6))
        #expect(LocalDay(key: "nope") == nil)
    }

    @Test func addingDaysCrossesMonthAndDST() {
        #expect(day(2026, 9, 30).adding(days: 1, calendar: .paris) == day(2026, 10, 1))
        #expect(day(2026, 10, 24).adding(days: 2, calendar: .paris) == day(2026, 10, 26))
        #expect(day(2026, 10, 1).adding(days: -1, calendar: .paris) == day(2026, 9, 30))
    }

    @Test func weekdayUsesCalendarConvention() {
        #expect(day(2026, 9, 26).weekday(calendar: .paris) == 7) // Saturday
        #expect(day(2026, 9, 27).weekday(calendar: .paris) == 1) // Sunday
    }

    @Test func ordering() {
        #expect(day(2026, 9, 30) < day(2026, 10, 1))
        #expect(!(day(2026, 10, 1) < day(2026, 10, 1)))
    }
}
