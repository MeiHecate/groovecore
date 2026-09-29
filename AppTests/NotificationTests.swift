import SwiftData
import XCTest
import UserNotifications
import GrooveKit
@testable import GrooveCore

@MainActor
final class NotificationTests: XCTestCase {
    let fr = Locale(identifier: "fr_FR"), en = Locale(identifier: "en_US")

    func testBodyInFrenchAndEnglish() {
        let items: [NotificationText.Item] = [
            .init(name: "Tractions", reps: 5, unit: .reps, perSide: false),
            .init(name: "Pistol squat", reps: 3, unit: .reps, perSide: true),
            .init(name: "Gainage", reps: 20, unit: .seconds, perSide: false),
        ]
        XCTAssertEqual(NotificationText.body(items, locale: fr), "Tractions 5 · Pistol squat 3/côté · Gainage 20 s")
        let enItems = [NotificationText.Item(name: "Plank", reps: 20, unit: .seconds, perSide: true)]
        XCTAssertEqual(NotificationText.body(enItems, locale: en), "Plank 20 s/side")
    }

    func testTitleUsesLocalTimeFormat() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        let date = cal.date(from: DateComponents(year: 2026, month: 9, day: 26, hour: 14, minute: 30))!
        XCTAssertEqual(NotificationText.title(for: date, locale: fr), "Bloc de 14:30")
        XCTAssertTrue(NotificationText.title(for: date, locale: en).hasSuffix(" block"))
        XCTAssertTrue(NotificationText.title(for: date, locale: en).contains("2:30"))
    }

    func testBuiltinNamesFollowLocale() throws {
        let container = try ModelContainer(for: Schema(GrooveStore.modelTypes),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let store = GrooveStore(context: container.mainContext)
        store.seedBuiltinsIfNeeded()
        let pull = store.exercises().first { $0.builtinKey == "pullups" }!
        let block = PlannedBlock(id: "b", date: .now, items: [PlannedItem(exerciseId: pull.id, reps: 5),
                                                              PlannedItem(exerciseId: UUID(), reps: 9)])
        XCTAssertEqual(NotificationText.body(NotificationText.items(for: block, store: store, locale: fr), locale: fr), "Tractions 5")
        XCTAssertEqual(NotificationText.body(NotificationText.items(for: block, store: store, locale: en), locale: en), "Pull-ups 5")
    }

    func testHandleDoneSkipAndTap() throws {
        let env = AppEnvironment(inMemory: true)
        let pull = env.store.exercises().first { $0.builtinKey == "pullups" }!
        let payload = BlockPayload(blockId: "2026-09-26-1430", items: [PlannedItem(exerciseId: pull.id, reps: 5)])
        let day = LocalDay(year: 2026, month: 9, day: 26)

        env.notifications.handle(actionIdentifier: NotificationCoordinator.doneAction, payload: payload, at: .now)
        env.notifications.handle(actionIdentifier: NotificationCoordinator.doneAction, payload: payload, at: .now)
        XCTAssertEqual(env.store.doneCounts(on: day), [pull.id: 1])

        let other = BlockPayload(blockId: "2026-09-26-1515", items: payload.items)
        env.notifications.handle(actionIdentifier: NotificationCoordinator.skipAction, payload: other, at: .now)
        XCTAssertEqual(env.store.skippedBlocks(on: day).map(\.blockId), ["2026-09-26-1515"])

        env.notifications.handle(actionIdentifier: UNNotificationDefaultActionIdentifier, payload: other, at: .now)
        XCTAssertEqual(env.notifications.openedBlock, other)
    }
}
