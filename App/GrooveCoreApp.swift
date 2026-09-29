import SwiftData
import SwiftUI

@main
struct GrooveCoreApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    private let env = AppEnvironment.shared

    init() {
        #if DEBUG
        DemoSeeder.seedIfRequested(env: AppEnvironment.shared)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(env.store)
                .environment(env.settings)
                .environment(env.notifications)
                .modelContainer(env.container)
                .tint(Theme.chalk)
                .background(Theme.ground)
                .onChange(of: env.settings.settings) { _, _ in env.dataChanged() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { env.appBecameActive() }
        }
    }
}
