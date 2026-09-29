import Foundation
import SwiftData

@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let container: ModelContainer
    let store: GrooveStore
    let settings: SettingsStore
    let notifications: NotificationCoordinator

    init(inMemory: Bool = false) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        container = try! ModelContainer(for: Schema(GrooveStore.modelTypes), configurations: configuration)
        store = GrooveStore(context: container.mainContext)
        settings = SettingsStore(defaults: inMemory ? UserDefaults(suiteName: "tests.\(UUID())")! : .standard)
        notifications = NotificationCoordinator(store: store, settings: settings)
        store.seedBuiltinsIfNeeded()
    }

    /// Call after any user edit that changes what should be scheduled.
    func dataChanged() {
        Task { await notifications.reschedule() }
    }

    func appBecameActive() {
        store.noteExternalChanges()
        dataChanged()
    }
}
