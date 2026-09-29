#if DEBUG
import Foundation
import GrooveKit

/// `-demo` launch argument: 6 programs, 20 days of history, onboarding done. Screenshots only.
enum DemoSeeder {
    @MainActor
    static func seedIfRequested(env: AppEnvironment) {
        guard ProcessInfo.processInfo.arguments.contains("-demo"), env.store.programs().isEmpty else { return }
        let calendar = env.store.calendar
        let now = Date()
        let settings = env.settings.settings
        let start = calendar.date(byAdding: .day, value: -21, to: now)!
        for (key, max) in [("pullups", 10), ("pushups", 24), ("dips", 12), ("squats", 30), ("pistolSquat", 6), ("plank", 60)] {
            if let exercise = env.store.exercises().first(where: { $0.builtinKey == key }) {
                env.store.activate(exercise, maxValue: max, settings: settings, at: start)
            }
        }
        let today = LocalDay(now, calendar: calendar)
        for back in 1...20 {
            let day = today.adding(days: -back, calendar: calendar)
            env.store.refreshDayTarget(for: day, settings: settings)
            let full = back % 6 != 3
            for program in env.store.programs() {
                let sets = full ? program.dailySets : program.dailySets / 2
                for i in 0..<sets {
                    env.store.logSet(exerciseId: program.exerciseId, reps: program.workingReps,
                                     at: day.date(minutesFromMidnight: 8 * 60 + i * 45, calendar: calendar))
                }
            }
        }
        for program in env.store.programs().prefix(3) {
            for i in 0..<3 {
                env.store.logSet(exerciseId: program.exerciseId, reps: program.workingReps,
                                 at: today.date(minutesFromMidnight: 8 * 60 + i * 45, calendar: calendar))
            }
        }
        env.settings.hasOnboarded = true
    }
}
#endif
