import Foundation
import Testing
@testable import GrooveKit

@Suite struct StreakRulesTests {
    let a = UUID(), b = UUID()

    @Test func statusRules() {
        #expect(StreakRules.status(targets: [a: 8], done: [:], isRestDay: true) == .rest)
        #expect(StreakRules.status(targets: [:], done: [:], isRestDay: false) == .none)
        #expect(StreakRules.status(targets: [a: 0], done: [:], isRestDay: false) == .none)
        #expect(StreakRules.status(targets: [a: 8, b: 6], done: [a: 8, b: 6], isRestDay: false) == .complete)
        #expect(StreakRules.status(targets: [a: 8, b: 6], done: [a: 9, b: 7], isRestDay: false) == .complete)
        #expect(StreakRules.status(targets: [a: 8, b: 6], done: [a: 8, b: 5], isRestDay: false) == .partial)
        #expect(StreakRules.status(targets: [a: 8, b: 6], done: [:], isRestDay: false) == .missed)
    }

    /// Mon 21 … Sat 26 Sept 2026, Sunday 20 is rest.
    func week(_ overrides: [Int: DayStatus] = [:]) -> [LocalDay: DayStatus] {
        var s: [LocalDay: DayStatus] = [:]
        for d in 14...26 { s[day(2026, 9, d)] = .complete }
        s[day(2026, 9, 20)] = .rest
        for (d, st) in overrides { s[day(2026, 9, d)] = st }
        return s
    }

    @Test func restDaysAreSkippedNotCounted() {
        // 14…19 (6) + 21…25 (5) = 11, today 26 incomplete
        #expect(StreakRules.currentStreak(statuses: week([26: .partial]), today: day(2026, 9, 26), calendar: .paris) == 11)
    }

    @Test func todayCountsOnlyWhenComplete() {
        #expect(StreakRules.currentStreak(statuses: week(), today: day(2026, 9, 26), calendar: .paris) == 12)
    }

    @Test func partialDayBreaks() {
        #expect(StreakRules.currentStreak(statuses: week([23: .partial, 26: .partial]), today: day(2026, 9, 26), calendar: .paris) == 2)
    }

    @Test func missingDayBreaks() {
        var s = week([26: .partial]); s[day(2026, 9, 24)] = nil
        #expect(StreakRules.currentStreak(statuses: s, today: day(2026, 9, 26), calendar: .paris) == 1)
    }

    @Test func emptyHistory() {
        #expect(StreakRules.currentStreak(statuses: [:], today: day(2026, 9, 26), calendar: .paris) == 0)
        #expect(StreakRules.longestStreak(statuses: [:], calendar: .paris) == 0)
    }

    @Test func allRestDaysTerminates() {
        let s: [LocalDay: DayStatus] = [day(2026, 9, 20): .rest, day(2026, 9, 27): .rest]
        #expect(StreakRules.currentStreak(statuses: s, today: day(2026, 9, 27), calendar: .paris) == 0)
    }

    @Test func longest() {
        #expect(StreakRules.longestStreak(statuses: week([17: .missed, 26: .partial]), calendar: .paris) == 7) // 18,19,21…25
    }
}
