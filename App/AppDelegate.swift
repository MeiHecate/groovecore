import BackgroundTasks
import UIKit
import UserNotifications
import GrooveKit

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Must be set before launch ends so "Done" works when iOS wakes a killed app.
        UNUserNotificationCenter.current().delegate = self
        MainActor.assumeIsolated { AppEnvironment.shared.notifications.registerCategories() }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: NotificationCoordinator.refreshTaskId, using: nil) { task in
            let work = Task { @MainActor in
                await AppEnvironment.shared.notifications.reschedule()
                task.setTaskCompleted(success: !Task.isCancelled)
            }
            task.expirationHandler = { work.cancel() }
        }
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        guard let payload = BlockPayload(userInfo: response.notification.request.content.userInfo) else { return }
        await Self.process(action: response.actionIdentifier, payload: payload)
    }

    @MainActor
    private static func process(action: String, payload: BlockPayload) async {
        let notifications = AppEnvironment.shared.notifications
        notifications.handle(actionIdentifier: action, payload: payload, at: .now)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [payload.blockId])
        await notifications.reschedule()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
