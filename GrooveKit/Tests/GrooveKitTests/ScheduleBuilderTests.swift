import Foundation
import Testing
@testable import GrooveKit

@Suite struct ScheduleBuilderTests {
    let a = ScheduleExercise(id: UUID(), order: 0, dailySets: 8, reps: 5)
    let b = ScheduleExercise(id: UUID(), order: 1, dailySets: 8, reps: 12)

    func input(now: Date, _ exercises: [ScheduleExercise], settings: GrooveSettings = GrooveSettings(),
               done: [UUID: Int] = [:], handled: Set<String> = []) -> ScheduleInput {
        ScheduleInput(now: now, settings: settings, exercises: exercises, doneToday: done,
                      handledBlockIds: handled, lastHandledExercises: [])
    }

    @Test func todayOnlyUsesFutureSlots() {
        let now = parisDate(2026, 9, 26, 12, 0)
        let plan = ScheduleBuilder.todayPlan(input(now: now, [a, b]), calendar: .paris)
        #expect(plan.blocks.first!.date > now)
        #expect(hm(plan.blocks.first!.date) == "12:30") // slots are 08:00 + 45 min steps
        #expect(plan.blocks.allSatisfy { LocalDay($0.date, calendar: .paris) == day(2026, 9, 26) })
    }

    @Test func doneSetsAreNotPlannedAgain() {
        let plan = ScheduleBuilder.todayPlan(input(now: parisDate(2026, 9, 26, 7, 0), [a, b], done: [a.id: 8, b.id: 6]), calendar: .paris)
        let items = plan.blocks.flatMap(\.items)
        #expect(!items.contains { $0.exerciseId == a.id })
        #expect(items.filter { $0.exerciseId == b.id }.count == 2)
    }

    @Test func handledSlotIsNotReused() {
        let now = parisDate(2026, 9, 26, 7, 0)
        let plan = ScheduleBuilder.todayPlan(input(now: now, [a], handled: ["2026-09-26-0800"]), calendar: .paris)
        #expect(!plan.blocks.contains { $0.id == "2026-09-26-0800" })
    }

    @Test func windowIsCappedAt60() {
        let blocks = ScheduleBuilder.upcomingBlocks(input(now: parisDate(2026, 9, 26, 7, 0), [a, b]), calendar: .paris)
        #expect(blocks.count == 60)
        #expect(Set(blocks.map(\.id)).count == 60)
        #expect(zip(blocks, blocks.dropFirst()).allSatisfy { $0.date < $1.date })
    }

    @Test func windowIsCappedAt14Days() {
        let one = ScheduleExercise(id: UUID(), order: 0, dailySets: 1, reps: 5)
        let blocks = ScheduleBuilder.upcomingBlocks(input(now: parisDate(2026, 9, 26, 7, 0), [one]), calendar: .paris)
        #expect(blocks.count == 14)
        #expect(LocalDay(blocks.last!.date, calendar: .paris) == day(2026, 10, 9))
    }

    @Test func restDaysGetNothing() {
        var s = GrooveSettings(); s.restWeekdays = Set(1...7)
        #expect(ScheduleBuilder.upcomingBlocks(input(now: parisDate(2026, 9, 26, 7, 0), [a], settings: s), calendar: .paris).isEmpty)
        s.restWeekdays = [1] // Sundays
        let blocks = ScheduleBuilder.upcomingBlocks(input(now: parisDate(2026, 9, 26, 7, 0), [a], settings: s), calendar: .paris)
        #expect(!blocks.contains { LocalDay($0.date, calendar: .paris).weekday(calendar: .paris) == 1 })
    }

    @Test func noExerciseNoBlocks() {
        #expect(ScheduleBuilder.upcomingBlocks(input(now: parisDate(2026, 9, 26, 7, 0), []), calendar: .paris).isEmpty)
    }

    @Test func capacityOverflowIgnoresRestDays() {
        var s = GrooveSettings(); s.restWeekdays = Set(1...7); s.maxBlockSize = 4
        let ten = (0..<10).map { ScheduleExercise(id: UUID(), order: $0, dailySets: 8, reps: 5) }
        #expect(ScheduleBuilder.capacityOverflow(exercises: ten, settings: s, referenceDay: day(2026, 9, 26), calendar: .paris) >= 12)
        #expect(ScheduleBuilder.capacityOverflow(exercises: [a, b], settings: s, referenceDay: day(2026, 9, 26), calendar: .paris) == 0)
    }
}
