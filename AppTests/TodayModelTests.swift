import SwiftData
import XCTest
import GrooveKit
@testable import GrooveCore

@MainActor
final class TodayModelTests: XCTestCase {
    var container: ModelContainer!
    var store: GrooveStore!

    override func setUp() async throws {
        container = try ModelContainer(for: Schema(GrooveStore.modelTypes),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        store = GrooveStore(context: container.mainContext)
        store.seedBuiltinsIfNeeded()
    }

    func testRowsNextBlockAndTotals() throws {
        let settings = GrooveSettings()
        let cal = store.calendar
        let now = cal.date(from: DateComponents(year: 2026, month: 9, day: 26, hour: 7))!
        let pull = store.exercises().first { $0.builtinKey == "pullups" }!
        let push = store.exercises().first { $0.builtinKey == "pushups" }!
        store.activate(pull, maxValue: 10, settings: settings, at: now)
        store.activate(push, maxValue: 24, settings: settings, at: now)
        store.logSet(exerciseId: pull.id, reps: 5, at: now)

        let model = TodayModel(store: store, settings: settings, now: now)
        XCTAssertEqual(model.rows.map(\.exercise.id), [pull.id, push.id])
        XCTAssertEqual(model.rows.map(\.done), [1, 0])
        XCTAssertEqual(model.totalDone, 1)
        XCTAssertEqual(model.totalGoal, 16)
        XCTAssertNotNil(model.nextBlock)
        XCTAssertGreaterThan(model.nextBlock!.date, now)
        XCTAssertFalse(model.isRestDay)
        XCTAssertTrue(model.retestDue.isEmpty)

        let later = cal.date(byAdding: .day, value: 10, to: now)!
        XCTAssertEqual(TodayModel(store: store, settings: settings, now: later).retestDue.count, 2)
    }

    func testRetestSummary() throws {
        let settings = GrooveSettings()
        let cal = store.calendar
        let now = cal.date(from: DateComponents(year: 2026, month: 9, day: 26, hour: 7))!
        let pull = store.exercises().first { $0.builtinKey == "pullups" }!
        store.activate(pull, maxValue: 10, settings: settings, at: now)

        let later = cal.date(byAdding: .day, value: 10, to: now)!
        XCTAssertEqual(TodayModel(store: store, settings: settings, now: later).retestSummary, pull.displayName())

        let push = store.exercises().first { $0.builtinKey == "pushups" }!
        let dips = store.exercises().first { $0.builtinKey == "dips" }!
        store.activate(push, maxValue: 24, settings: settings, at: now)
        store.activate(dips, maxValue: 8, settings: settings, at: now)

        let threeDue = TodayModel(store: store, settings: settings, now: later)
        XCTAssertEqual(threeDue.retestDue.count, 3)
        XCTAssertEqual(threeDue.retestSummary, "\(pull.displayName()), \(push.displayName()) +1")
    }

    func testOverflowWhenBlockSizeIsTooSmall() throws {
        var settings = GrooveSettings()
        settings.maxBlockSize = 4
        let cal = store.calendar
        let now = cal.date(from: DateComponents(year: 2026, month: 9, day: 26, hour: 7))!
        for exercise in store.exercises() {
            store.activate(exercise, maxValue: 10, settings: settings, at: now)
        }

        XCTAssertGreaterThan(TodayModel(store: store, settings: settings, now: now).overflow, 0)
    }
}
