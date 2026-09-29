import Testing
@testable import GrooveKit

@Suite struct ProgramRulesTests {
    @Test func roundsToNearestHalfUp() {
        #expect(ProgramRules.workingReps(maxValue: 10, workPercent: 50, manualReps: nil) == 5)
        #expect(ProgramRules.workingReps(maxValue: 7, workPercent: 50, manualReps: nil) == 4)  // 3.5 → 4
        #expect(ProgramRules.workingReps(maxValue: 9, workPercent: 40, manualReps: nil) == 4)  // 3.6 → 4
        #expect(ProgramRules.workingReps(maxValue: 11, workPercent: 30, manualReps: nil) == 3) // 3.3 → 3
    }

    @Test func neverBelowOne() {
        #expect(ProgramRules.workingReps(maxValue: 1, workPercent: 30, manualReps: nil) == 1)
        #expect(ProgramRules.workingReps(maxValue: 0, workPercent: 50, manualReps: nil) == 1)
    }

    @Test func manualRepsWin() {
        #expect(ProgramRules.workingReps(maxValue: 10, workPercent: 50, manualReps: 7) == 7)
        #expect(ProgramRules.workingReps(maxValue: 10, workPercent: 50, manualReps: 0) == 1)
    }

    @Test func retestDueBoundaries() {
        let last = day(2026, 9, 18)
        #expect(!ProgramRules.isRetestDue(lastTestDay: last, intervalDays: 10, today: day(2026, 9, 27), calendar: .paris))
        #expect(ProgramRules.isRetestDue(lastTestDay: last, intervalDays: 10, today: day(2026, 9, 28), calendar: .paris))
        #expect(ProgramRules.isRetestDue(lastTestDay: last, intervalDays: 10, today: day(2026, 10, 5), calendar: .paris))
        #expect(ProgramRules.nextRetestDay(lastTestDay: last, intervalDays: 10, calendar: .paris) == day(2026, 9, 28))
    }

    @Test func retestWithoutManualRepsUpdates() {
        #expect(ProgramRules.retestOutcome(newMax: 12, workPercent: 50, manualReps: nil) == .updated(newReps: 6))
    }

    @Test func retestWithManualRepsAsks() {
        #expect(ProgramRules.retestOutcome(newMax: 12, workPercent: 50, manualReps: 4)
                == .needsConfirmation(manualReps: 4, recalculatedReps: 6))
    }
}
