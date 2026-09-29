import Foundation
import GrooveKit

@MainActor
struct TodayModel {
    struct Row: Identifiable {
        let id: UUID
        let exercise: Exercise
        let program: Program
        let done: Int
        let goal: Int
    }

    let today: LocalDay
    let isRestDay: Bool
    let nextBlock: PlannedBlock?
    let rows: [Row]
    let streak: Int
    let retestDue: [Row]
    let overflow: Int

    var totalDone: Int { rows.reduce(0) { $0 + min($1.done, $1.goal) } }
    var totalGoal: Int { rows.reduce(0) { $0 + $1.goal } }

    /// First two due exercise names, joined, plus " +N" if more are due. Nil when none are due.
    var retestSummary: String? {
        guard !retestDue.isEmpty else { return nil }
        let names = retestDue.map { $0.exercise.displayName() }
        let shown = names.prefix(2).joined(separator: ", ")
        let extra = names.count - 2
        return extra > 0 ? "\(shown) +\(extra)" : shown
    }

    init(store: GrooveStore, settings: GrooveSettings, now: Date) {
        let calendar = store.calendar
        let day = LocalDay(now, calendar: calendar)
        let done = store.doneCounts(on: day)
        let built: [Row] = store.programs().compactMap { program in
            guard let exercise = store.exercise(id: program.exerciseId), !exercise.isArchived else { return nil }
            return Row(id: program.id, exercise: exercise, program: program,
                       done: done[exercise.id, default: 0], goal: program.dailySets)
        }
        today = day
        isRestDay = settings.isRestDay(day, calendar: calendar)
        rows = built
        let scheduleInput = store.scheduleInput(now: now, settings: settings)
        nextBlock = ScheduleBuilder.todayPlan(scheduleInput, calendar: calendar).blocks.first
        streak = StreakRules.currentStreak(statuses: store.dayStatuses(through: day, settings: settings),
                                           today: day, calendar: calendar)
        retestDue = built.filter {
            ProgramRules.isRetestDue(lastTestDay: LocalDay($0.program.lastTestDate, calendar: calendar),
                                     intervalDays: $0.program.retestIntervalDays, today: day, calendar: calendar)
        }
        overflow = ScheduleBuilder.capacityOverflow(exercises: scheduleInput.exercises, settings: settings,
                                                    referenceDay: day, calendar: calendar)
    }
}
