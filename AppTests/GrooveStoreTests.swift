import SwiftData
import XCTest
import GrooveKit
@testable import GrooveCore

@MainActor
final class GrooveStoreTests: XCTestCase {
    var container: ModelContainer!
    var store: GrooveStore!
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Paris")!
        return c
    }()

    func at(_ d: Int, _ h: Int, _ m: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 9, day: d, hour: h, minute: m))!
    }

    override func setUp() async throws {
        container = try ModelContainer(for: Schema(GrooveStore.modelTypes),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        store = GrooveStore(context: container.mainContext, calendar: cal)
        store.seedBuiltinsIfNeeded()
    }

    func builtin(_ key: String) -> Exercise { store.exercises().first { $0.builtinKey == key }! }

    func testSeedIsIdempotentAndOrdered() {
        store.seedBuiltinsIfNeeded()
        XCTAssertEqual(store.exercises().map(\.builtinKey), ExerciseCatalog.builtins.map(\.key))
    }

    func testDoneFromNotificationIsIdempotent() {
        let pull = builtin("pullups"), push = builtin("pushups")
        let payload = BlockPayload(blockId: "2026-09-26-1430", items: [
            PlannedItem(exerciseId: pull.id, reps: 5), PlannedItem(exerciseId: push.id, reps: 12)])
        XCTAssertTrue(store.logBlock(payload, at: at(26, 14, 31)))
        XCTAssertFalse(store.logBlock(payload, at: at(26, 14, 32)))
        XCTAssertEqual(store.setLogs(on: LocalDay(year: 2026, month: 9, day: 26)).count, 2)
    }

    func testStaleNotificationIgnoresUnknownExercises() {
        let pull = builtin("pullups")
        let payload = BlockPayload(blockId: "2026-09-26-1430", items: [
            PlannedItem(exerciseId: UUID(), reps: 5), PlannedItem(exerciseId: pull.id, reps: 5)])
        XCTAssertTrue(store.logBlock(payload, at: at(26, 14, 31)))
        XCTAssertEqual(store.doneCounts(on: LocalDay(year: 2026, month: 9, day: 26)), [pull.id: 1])
    }

    func testLateLogCountsForTheBlockDay() {
        let pull = builtin("pullups")
        store.logBlock(BlockPayload(blockId: "2026-09-26-2000", items: [PlannedItem(exerciseId: pull.id, reps: 5)]), at: at(27, 0, 10))
        XCTAssertEqual(store.doneCounts(on: LocalDay(year: 2026, month: 9, day: 26)), [pull.id: 1])
    }

    func testSkipIsHandledAndRemembered() {
        let settings = GrooveSettings()
        let pull = builtin("pullups")
        store.activate(pull, maxValue: 10, settings: settings, at: at(26, 7))
        let payload = BlockPayload(blockId: "2026-09-26-0800", items: [PlannedItem(exerciseId: pull.id, reps: 5)])
        store.skipBlock(payload, at: at(26, 8, 1))
        store.skipBlock(payload, at: at(26, 8, 2))
        let input = store.scheduleInput(now: at(26, 8, 5), settings: settings)
        XCTAssertEqual(input.handledBlockIds, ["2026-09-26-0800"])
        XCTAssertEqual(input.lastHandledExercises, [pull.id])
        XCTAssertEqual(input.doneToday, [:])
        XCTAssertEqual(store.skippedBlocks(on: LocalDay(year: 2026, month: 9, day: 26)).count, 1)
    }

    func testUndoRemovesTheBlock() {
        let pull = builtin("pullups")
        store.logBlock(BlockPayload(blockId: "2026-09-26-0800", items: [PlannedItem(exerciseId: pull.id, reps: 5)]), at: at(26, 8))
        store.undoBlock(blockId: "2026-09-26-0800")
        XCTAssertEqual(store.doneCounts(on: LocalDay(year: 2026, month: 9, day: 26)), [:])
    }

    func testUndoManualSet() {
        let pull = builtin("pullups")
        store.activate(pull, maxValue: 10, settings: GrooveSettings(), at: at(26, 7))
        let setId = store.logSet(exerciseId: pull.id, reps: 5, at: at(26, 8))
        XCTAssertEqual(store.doneCounts(on: LocalDay(year: 2026, month: 9, day: 26)), [pull.id: 1])
        store.undoSet(id: setId)
        XCTAssertEqual(store.doneCounts(on: LocalDay(year: 2026, month: 9, day: 26)), [:])
        store.undoSet(id: setId) // no-op, already gone
    }

    func testDoneTodayResetsAtLocalMidnight() {
        let settings = GrooveSettings()
        let pull = builtin("pullups")
        store.activate(pull, maxValue: 10, settings: settings, at: at(26, 7))
        store.logSet(exerciseId: pull.id, reps: 5, at: at(26, 23, 59))
        XCTAssertEqual(store.scheduleInput(now: at(26, 23, 59), settings: settings).doneToday, [pull.id: 1])
        XCTAssertEqual(store.scheduleInput(now: at(27, 0, 1), settings: settings).doneToday, [:])
    }

    func testCustomExerciseDeleteOrArchive() throws {
        let fresh = try store.createCustomExercise(name: "Muscle-up", unit: .reps, perSide: false)
        XCTAssertEqual(store.deleteOrArchive(fresh), .deleted)
        XCTAssertNil(store.exercise(id: fresh.id))

        let used = try store.createCustomExercise(name: "Muscle-up", unit: .reps, perSide: false)
        let program = store.activate(used, maxValue: 3, settings: GrooveSettings())
        XCTAssertFalse(store.canChangeUnit(used))
        XCTAssertEqual(store.deleteOrArchive(used), .archived)
        XCTAssertTrue(used.isArchived)
        XCTAssertFalse(program.isActive)
        XCTAssertNoThrow(try store.createCustomExercise(name: "muscle-up", unit: .reps, perSide: false))
    }

    func testBuiltinIsNeverDeleted() {
        let pull = builtin("pullups")
        let program = store.activate(pull, maxValue: 10, settings: GrooveSettings())
        XCTAssertEqual(store.deleteOrArchive(pull), .archived)
        let stillThere = store.exercise(id: pull.id)
        XCTAssertEqual(stillThere?.id, pull.id)
        XCTAssertEqual(stillThere?.isArchived, false)
        XCTAssertFalse(program.isActive)
    }

    func testArchivedExerciseIsIgnoredWhenLogging() throws {
        let pull = builtin("pullups")
        let custom = try store.createCustomExercise(name: "Muscle-up", unit: .reps, perSide: false)
        store.activate(custom, maxValue: 5, settings: GrooveSettings()) // gives it history via MaxTest
        XCTAssertEqual(store.deleteOrArchive(custom), .archived)
        let payload = BlockPayload(blockId: "2026-09-26-1430", items: [
            PlannedItem(exerciseId: custom.id, reps: 5), PlannedItem(exerciseId: pull.id, reps: 5)])
        XCTAssertTrue(store.logBlock(payload, at: at(26, 14, 31)))
        XCTAssertEqual(store.doneCounts(on: LocalDay(year: 2026, month: 9, day: 26)), [pull.id: 1])
    }

    func testCustomNameValidation() {
        XCTAssertThrowsError(try store.createCustomExercise(name: "  ", unit: .reps, perSide: false)) {
            XCTAssertEqual($0 as? ExerciseNameError, .empty)
        }
        XCTAssertThrowsError(try store.createCustomExercise(name: builtin("pullups").displayName(), unit: .reps, perSide: false)) {
            XCTAssertEqual($0 as? ExerciseNameError, .duplicate)
        }
    }

    func testRetestWithManualRepsAsks() {
        let program = store.activate(builtin("pullups"), maxValue: 10, settings: GrooveSettings())
        store.update(program) { $0.manualReps = 4 }
        XCTAssertEqual(store.recordMaxTest(program, value: 12, at: at(28, 9)),
                       .needsConfirmation(manualReps: 4, recalculatedReps: 6))
        XCTAssertEqual(program.maxValue, 12)
        store.useRecalculatedReps(program)
        XCTAssertEqual(program.workingReps, 6)
        XCTAssertEqual(store.maxTests(exerciseId: program.exerciseId).count, 2)
    }

    func testDayStatusesUseTargets() {
        var settings = GrooveSettings()
        settings.restWeekdays = [1]
        let pull = builtin("pullups")
        let program = store.activate(pull, maxValue: 10, settings: settings, at: at(25, 7))
        store.update(program) { $0.dailySets = 2 }
        let d25 = LocalDay(year: 2026, month: 9, day: 25), d26 = LocalDay(year: 2026, month: 9, day: 26)
        store.refreshDayTarget(for: d25, settings: settings)
        store.refreshDayTarget(for: d26, settings: settings)
        store.logSet(exerciseId: pull.id, reps: 5, at: at(25, 9))
        store.logSet(exerciseId: pull.id, reps: 5, at: at(25, 10))
        store.logSet(exerciseId: pull.id, reps: 5, at: at(26, 9))
        let statuses = store.dayStatuses(through: LocalDay(year: 2026, month: 9, day: 27), settings: settings)
        XCTAssertEqual(statuses[d25], .complete)
        XCTAssertEqual(statuses[d26], .partial)
        XCTAssertEqual(statuses[LocalDay(year: 2026, month: 9, day: 27)], .rest)
    }

    func testReorderAndResume() {
        let a = store.activate(builtin("pullups"), maxValue: 10, settings: GrooveSettings())
        let b = store.activate(builtin("pushups"), maxValue: 20, settings: GrooveSettings())
        store.moveActivePrograms(from: IndexSet(integer: 1), to: 0)
        XCTAssertEqual(store.programs().map(\.id), [b.id, a.id])
        store.setActive(b, false)
        XCTAssertEqual(store.programs().map(\.id), [a.id])
        store.setActive(b, true)
        XCTAssertEqual(store.programs().map(\.id), [a.id, b.id])
    }
}
