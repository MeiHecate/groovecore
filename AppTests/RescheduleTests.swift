import SwiftData
import XCTest
import UserNotifications
import GrooveKit
@testable import GrooveCore

@MainActor
final class RescheduleTests: XCTestCase {
    final class FakeCenter: NotificationScheduling {
        var status: UNAuthorizationStatus = .authorized
        private(set) var requests: [UNNotificationRequest] = []

        /// When true, the next `add()` call blocks (see below) instead of completing immediately,
        /// so a test can force a specific interleaving between two concurrent `reschedule()` calls.
        var gateNextAdd = false
        private(set) var isBlockedInAdd = false
        private var gate: CheckedContinuation<Void, Never>?

        func authorizationStatus() async -> UNAuthorizationStatus { status }

        func removeAllPendingNotificationRequests() { requests.removeAll() }

        /// Releases whichever `add()` call is currently parked in the gate, if any.
        func releaseGate() {
            gate?.resume()
            gate = nil
        }

        func add(_ request: UNNotificationRequest) async throws {
            if gateNextAdd {
                gateNextAdd = false
                isBlockedInAdd = true
                await withCheckedContinuation { gate = $0 }
                isBlockedInAdd = false
            } else {
                await Task.yield()
            }
            requests.removeAll { $0.identifier == request.identifier }
            requests.append(request)
        }
    }

    var container: ModelContainer!
    var store: GrooveStore!
    var settings: SettingsStore!
    let fixedNow: Date = {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        return cal.date(from: DateComponents(year: 2026, month: 9, day: 26, hour: 7, minute: 0))!
    }()

    override func setUp() async throws {
        container = try ModelContainer(for: Schema(GrooveStore.modelTypes),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        store = GrooveStore(context: container.mainContext)
        store.seedBuiltinsIfNeeded()
        settings = SettingsStore(defaults: UserDefaults(suiteName: "tests.\(UUID())")!)
        let pull = store.exercises().first { $0.builtinKey == "pullups" }!
        let push = store.exercises().first { $0.builtinKey == "pushups" }!
        store.activate(pull, maxValue: 10, settings: settings.settings)
        store.activate(push, maxValue: 24, settings: settings.settings)
    }

    /// Runs `reschedule()` from a Task and blocks (pumping the run loop) until it completes.
    private func runAndWait(_ label: String, _ operation: @escaping () async -> Void) {
        let done = expectation(description: label)
        Task { @MainActor in
            await operation()
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
    }

    func testRequestsMatchThePlan() throws {
        let fake = FakeCenter()
        let coordinator = NotificationCoordinator(store: store, settings: settings, center: fake)

        runAndWait("reschedule") { await coordinator.reschedule(now: self.fixedNow) }

        XCTAssertTrue((1...60).contains(fake.requests.count))
        let identifiers = fake.requests.map(\.identifier)
        XCTAssertEqual(Set(identifiers).count, identifiers.count)

        let idPattern = try NSRegularExpression(pattern: "^\\d{4}-\\d{2}-\\d{2}-\\d{4}$")
        for request in fake.requests {
            let identifier = request.identifier
            XCTAssertNotNil(idPattern.firstMatch(in: identifier, range: NSRange(identifier.startIndex..., in: identifier)),
                            "identifier \(identifier) should match yyyy-MM-dd-HHmm")
            XCTAssertEqual(request.content.categoryIdentifier, NotificationCoordinator.categoryId)
            guard let trigger = request.trigger as? UNCalendarNotificationTrigger else {
                XCTFail("expected a calendar trigger for \(identifier)")
                continue
            }
            XCTAssertFalse(trigger.repeats)
            let hhmm = String(identifier.suffix(4))
            XCTAssertEqual(trigger.dateComponents.hour, Int(hhmm.prefix(2)))
            XCTAssertEqual(trigger.dateComponents.minute, Int(hhmm.suffix(2)))
            guard let payload = BlockPayload(userInfo: request.content.userInfo) else {
                XCTFail("expected a decodable payload for \(identifier)")
                continue
            }
            XCTAssertEqual(payload.blockId, identifier)
        }
    }

    func testConcurrentReschedulesLeaveOnlyTheLatestPlan() async throws {
        // Pausing pull-ups rather than push-ups here is deliberate, not cosmetic: pull-ups is
        // program order 0 (phase 0), so `BlockPlanner` always assigns it to the very first slot,
        // while push-ups (order 1, phase ≈0.618 with 16 slots and 8 sets) only starts from the
        // second slot onward. `FakeCenter.gateNextAdd` blocks exactly the *first* `add()` call, i.e.
        // the first scheduled block — so it must contain the exercise we pause, or the gated block
        // would never carry the stale data the race is about, and the test would pass vacuously
        // regardless of whether `reschedule()` is actually serialized. Confirmed empirically: with
        // push-ups paused instead, this test passed even against a deliberately unserialized
        // `reschedule()` (see the round-3 fix report for the recorded failing-then-passing runs).
        let pullId = store.exercises().first { $0.builtinKey == "pullups" }!.id
        let pullProgram = store.program(exerciseId: pullId)!

        // Sanity check: with both exercises still active, a solo reschedule's plan does include
        // pull-ups. Without this, the "no pull-ups after concurrent reschedules" assertion below
        // could pass vacuously (e.g. if the plan never included pull-ups to begin with).
        let sanityFake = FakeCenter()
        let sanityCoordinator = NotificationCoordinator(store: store, settings: settings, center: sanityFake)
        await sanityCoordinator.reschedule(now: fixedNow)
        XCTAssertTrue(sanityFake.requests.contains { request in
            BlockPayload(userInfo: request.content.userInfo)?.items.contains { $0.exerciseId == pullId } ?? false
        }, "expected the solo plan to include pull-ups before pausing it")

        let fake = FakeCenter()
        let coordinator = NotificationCoordinator(store: store, settings: settings, center: fake)

        // Force the interleaving deterministically instead of hoping for it: gate A's first add()
        // so it parks mid-flight, holding the pre-pause plan, while we pause pull-ups and start B.
        fake.gateNextAdd = true
        let taskA = Task { @MainActor in await coordinator.reschedule(now: self.fixedNow) }
        let deadline = Date().addingTimeInterval(5)
        while !fake.isBlockedInAdd {
            if Date() > deadline {
                XCTFail("timed out waiting for the first add to block")
                return
            }
            await Task.yield()
        }

        // A is now suspended inside its first add(), holding the pre-pause plan.
        store.setActive(pullProgram, false)
        let taskB = Task { @MainActor in await coordinator.reschedule(now: self.fixedNow) }
        for _ in 0..<5 { await Task.yield() }
        fake.releaseGate()

        await taskA.value
        await taskB.value

        let identifiers = fake.requests.map(\.identifier)
        XCTAssertEqual(Set(identifiers).count, identifiers.count, "no duplicate identifiers after concurrent reschedules")
        XCTAssertLessThanOrEqual(fake.requests.count, 60)

        for request in fake.requests {
            guard let payload = BlockPayload(userInfo: request.content.userInfo) else {
                XCTFail("expected a decodable payload for \(request.identifier)")
                continue
            }
            XCTAssertFalse(payload.items.contains { $0.exerciseId == pullId },
                           "pull-ups should not appear in any pending request once B superseded A")
        }
    }

    func testDeniedSchedulesNothing() throws {
        let fake = FakeCenter()
        fake.status = .denied
        let coordinator = NotificationCoordinator(store: store, settings: settings, center: fake)

        runAndWait("reschedule") { await coordinator.reschedule(now: self.fixedNow) }

        XCTAssertEqual(fake.requests.count, 0)
    }
}
