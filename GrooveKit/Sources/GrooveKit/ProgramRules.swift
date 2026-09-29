import Foundation

public enum ProgramRules {
    public enum RetestOutcome: Equatable, Sendable {
        case updated(newReps: Int)
        case needsConfirmation(manualReps: Int, recalculatedReps: Int)
    }

    /// Manual reps if set, else max × percent rounded to nearest (half up). Never below 1.
    public static func workingReps(maxValue: Int, workPercent: Int, manualReps: Int?) -> Int {
        if let manualReps { return max(1, manualReps) }
        return max(1, (maxValue * workPercent + 50) / 100)
    }

    public static func nextRetestDay(lastTestDay: LocalDay, intervalDays: Int, calendar: Calendar) -> LocalDay {
        lastTestDay.adding(days: intervalDays, calendar: calendar)
    }

    public static func isRetestDue(lastTestDay: LocalDay, intervalDays: Int, today: LocalDay, calendar: Calendar) -> Bool {
        today >= nextRetestDay(lastTestDay: lastTestDay, intervalDays: intervalDays, calendar: calendar)
    }

    public static func retestOutcome(newMax: Int, workPercent: Int, manualReps: Int?) -> RetestOutcome {
        let recalculated = workingReps(maxValue: newMax, workPercent: workPercent, manualReps: nil)
        if let manualReps { return .needsConfirmation(manualReps: manualReps, recalculatedReps: recalculated) }
        return .updated(newReps: recalculated)
    }
}
