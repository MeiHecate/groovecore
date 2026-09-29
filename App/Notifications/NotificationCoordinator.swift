import BackgroundTasks
import Foundation
import Observation
import UserNotifications
import GrooveKit

/// Notification scheduling surface consumed by `NotificationCoordinator`, so tests can substitute
/// a fake center instead of the real `UNUserNotificationCenter`.
protocol NotificationScheduling: AnyObject {
    func authorizationStatus() async -> UNAuthorizationStatus
    func removeAllPendingNotificationRequests()
    func add(_ request: UNNotificationRequest) async throws
}

extension UNUserNotificationCenter: NotificationScheduling {
    func authorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }
}

@MainActor @Observable
final class NotificationCoordinator {
    static let categoryId = "BLOCK"
    static let doneAction = "DONE"
    static let skipAction = "SKIP"
    static let refreshTaskId = "com.maelrochard.groovecore.reschedule"

    @ObservationIgnored private let store: GrooveStore
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let center: NotificationScheduling
    /// Bumped at the start of every reschedule(); a run whose generation goes stale mid-flight
    /// (because a newer reschedule started) abandons at its next check instead of applying an
    /// outdated plan on top of, or after, the newer one.
    @ObservationIgnored private var generation = 0
    /// The task chain used to truly serialize reschedule() calls (see reschedule()).
    @ObservationIgnored private var inFlight: Task<Void, Never>?

    var authorization: UNAuthorizationStatus = .notDetermined
    /// Set when the user taps a notification; Today presents the block detail.
    var openedBlock: BlockPayload?

    var isAuthorized: Bool { authorization == .authorized || authorization == .provisional }

    init(store: GrooveStore, settings: SettingsStore, center: NotificationScheduling = UNUserNotificationCenter.current()) {
        self.store = store
        self.settings = settings
        self.center = center
    }

    func registerCategories() {
        let done = UNNotificationAction(identifier: Self.doneAction, title: tr("action.done"), options: [])
        let skip = UNNotificationAction(identifier: Self.skipAction, title: tr("action.skip"), options: [])
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: Self.categoryId, actions: [done, skip], intentIdentifiers: [], options: []),
        ])
    }

    func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        await refreshAuthorization()
    }

    func refreshAuthorization() async {
        authorization = await center.authorizationStatus()
    }

    /// Clears pending reminders and schedules the next ones (max 60, max 14 days).
    ///
    /// Truly serialized via a task chain, not just the `generation` counter: each call captures
    /// whatever run is currently in flight and awaits it before doing anything else, so at most one
    /// run ever touches `center` at a time. This closes a race the counter alone couldn't: without
    /// the chain, an `add` already in flight for a stale generation could complete right after a
    /// newer generation's `removeAllPendingNotificationRequests()`, leaving a stale request pending.
    /// A run superseded before it even starts (a newer `reschedule()` arrived while it was still
    /// waiting for its predecessor) bails out immediately without touching the center at all.
    func reschedule(now: Date = .now) async {
        generation += 1
        let mine = generation
        let previous = inFlight
        let task = Task { @MainActor in
            await previous?.value
            guard mine == self.generation else { return }
            await self.performReschedule(now: now, generation: mine)
        }
        inFlight = task
        await task.value
    }

    /// The actual work of `reschedule()`, run strictly one at a time via the task chain above.
    /// Still re-checks `generation` after every suspension point, so a run that goes stale *during*
    /// its own execution (not just before starting) abandons instead of applying an outdated plan.
    private func performReschedule(now: Date, generation mine: Int) async {
        await refreshAuthorization()
        guard mine == generation else { return }

        let current = settings.settings
        store.refreshDayTarget(for: LocalDay(now, calendar: store.calendar), settings: current)
        center.removeAllPendingNotificationRequests()
        guard isAuthorized else { return }

        let blocks = ScheduleBuilder.upcomingBlocks(store.scheduleInput(now: now, settings: current), calendar: store.calendar)
        let requests: [UNNotificationRequest] = blocks.compactMap { block in
            let items = NotificationText.items(for: block, store: store, locale: .current)
            guard !items.isEmpty else { return nil }
            let content = UNMutableNotificationContent()
            content.title = NotificationText.title(for: block.date, locale: .current)
            content.body = NotificationText.body(items, locale: .current)
            content.categoryIdentifier = Self.categoryId
            content.threadIdentifier = "blocks"
            content.userInfo = BlockPayload(block: block).userInfo
            if current.soundEnabled { content.sound = .default }
            let components = store.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: block.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            return UNNotificationRequest(identifier: block.id, content: content, trigger: trigger)
        }

        for request in requests {
            guard mine == generation else { return }
            try? await center.add(request)
        }
        scheduleBackgroundRefresh(after: now)
    }

    func handle(actionIdentifier: String, payload: BlockPayload, at date: Date) {
        switch actionIdentifier {
        case Self.doneAction: store.logBlock(payload, at: date)
        case Self.skipAction: store.skipBlock(payload, at: date)
        case UNNotificationDefaultActionIdentifier: openedBlock = payload
        default: break
        }
    }

    func scheduleBackgroundRefresh(after now: Date) {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskId)
        let tomorrow = LocalDay(now, calendar: store.calendar).adding(days: 1, calendar: store.calendar)
        request.earliestBeginDate = tomorrow.date(minutesFromMidnight: 5 * 60, calendar: store.calendar)
        try? BGTaskScheduler.shared.submit(request)
    }
}
