import Foundation
import Testing
@testable import GrooveKit

@Suite struct BlockPlannerTests {
    func slots(_ n: Int) -> [Date] {
        (0..<n).map { parisDate(2026, 9, 26, 8, 0).addingTimeInterval(Double($0) * 45 * 60) }
    }
    func ex(_ order: Int, _ sets: Int, reps: Int = 5) -> PlannerExercise {
        PlannerExercise(id: UUID(), order: order, remainingSets: sets, reps: reps)
    }
    func counts(_ plan: DayPlan) -> [UUID: Int] {
        plan.blocks.flatMap(\.items).reduce(into: [:]) { $0[$1.exerciseId, default: 0] += 1 }
    }

    @Test func noExercisesNoBlocks() {
        let plan = BlockPlanner.plan(slots: slots(17), exercises: [], maxBlockSize: 4, previousBlock: [], calendar: .paris)
        #expect(plan.blocks.isEmpty)
        #expect(plan.overflowSets == 0)
    }

    @Test func noSlotsEverythingOverflows() {
        let plan = BlockPlanner.plan(slots: [], exercises: [ex(0, 3), ex(1, 2)], maxBlockSize: 4, previousBlock: [], calendar: .paris)
        #expect(plan.blocks.isEmpty)
        #expect(plan.overflowSets == 5)
    }

    @Test func everySetPlacedWhenItFits() {
        let exercises = [ex(0, 8), ex(1, 8), ex(2, 8)]
        let plan = BlockPlanner.plan(slots: slots(17), exercises: exercises, maxBlockSize: 4, previousBlock: [], calendar: .paris)
        #expect(plan.overflowSets == 0)
        #expect(counts(plan) == Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, 8) }))
        for block in plan.blocks {
            #expect(block.items.count <= 4)
            #expect(Set(block.items.map(\.exerciseId)).count == block.items.count)
        }
    }

    @Test func noBackToBackWhenAvoidable() {
        let exercises = [ex(0, 2), ex(1, 2), ex(2, 2)]
        let plan = BlockPlanner.plan(slots: slots(6), exercises: exercises, maxBlockSize: 1, previousBlock: [], calendar: .paris)
        let sequence = plan.blocks.map { $0.items[0].exerciseId }
        #expect(sequence.count == 6)
        for i in 1..<sequence.count { #expect(sequence[i] != sequence[i - 1]) }
    }

    @Test func singleExerciseIsSpreadOverTheDay() {
        let plan = BlockPlanner.plan(slots: slots(16), exercises: [ex(0, 4)], maxBlockSize: 4, previousBlock: [], calendar: .paris)
        let indices = plan.blocks.map { b in slots(16).firstIndex(of: b.date)! }
        #expect(indices == [0, 4, 8, 12])
    }

    @Test func overflowWhenDayIsTooShort() {
        let exercises = (0..<10).map { ex($0, 8) }
        let plan = BlockPlanner.plan(slots: slots(17), exercises: exercises, maxBlockSize: 4, previousBlock: [], calendar: .paris)
        let placed = plan.blocks.reduce(0) { $0 + $1.items.count }
        #expect(placed + plan.overflowSets == 80)
        #expect(plan.overflowSets >= 12)
        #expect(plan.blocks.allSatisfy { $0.items.count <= 4 })
    }

    @Test func oneExerciseWithMoreSetsThanSlotsOverflowsTheRest() {
        let plan = BlockPlanner.plan(slots: slots(17), exercises: [ex(0, 20)], maxBlockSize: 4, previousBlock: [], calendar: .paris)
        #expect(plan.blocks.count == 17)
        #expect(plan.overflowSets == 3)
    }

    @Test func previousBlockIsNotRepeatedFirst() {
        let a = ex(0, 2), b = ex(1, 2)
        let plan = BlockPlanner.plan(slots: slots(6), exercises: [a, b], maxBlockSize: 4, previousBlock: [a.id], calendar: .paris)
        let firstSlotId = BlockPlanner.blockId(for: slots(6)[0], calendar: .paris)
        #expect(plan.blocks.first { $0.id == firstSlotId }?.items.contains { $0.exerciseId == a.id } != true)
        #expect(counts(plan)[a.id] == 2)
    }

    @Test func repsAndIdsAreCarried() {
        let a = ex(0, 1, reps: 12)
        let plan = BlockPlanner.plan(slots: slots(3), exercises: [a], maxBlockSize: 4, previousBlock: [], calendar: .paris)
        #expect(plan.blocks[0].items == [PlannedItem(exerciseId: a.id, reps: 12)])
        #expect(plan.blocks[0].id == "2026-09-26-0800")
        #expect(BlockPlanner.blockId(for: parisDate(2026, 10, 25, 20, 5), calendar: .paris) == "2026-10-25-2005")
    }

    @Test func itemsFollowProgramOrder() {
        let a = ex(1, 1), b = ex(0, 1)
        let plan = BlockPlanner.plan(slots: slots(1), exercises: [a, b], maxBlockSize: 4, previousBlock: [], calendar: .paris)
        #expect(plan.blocks[0].items.map(\.exerciseId) == [b.id, a.id])
    }
}
