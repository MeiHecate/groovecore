import SwiftUI

struct RootView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(NotificationCoordinator.self) private var notifications
    /// `-tab N` launch argument selects the first tab (used by the screenshot script).
    @State private var tab = UserDefaults.standard.integer(forKey: "tab")

    var body: some View {
        Group {
            if settingsStore.hasOnboarded {
                TabView(selection: $tab) {
                    Tab(tr("tab.today"), systemImage: "line.3.horizontal", value: 0) { TodayView(tab: $tab).tint(Theme.chalk) }
                    Tab(tr("tab.program"), systemImage: "list.bullet", value: 1) { ProgramView().tint(Theme.chalk) }
                    Tab(tr("tab.history"), systemImage: "calendar", value: 2) { HistoryView().tint(Theme.chalk) }
                    Tab(tr("tab.settings"), systemImage: "slider.horizontal.3", value: 3) { SettingsView().tint(Theme.chalk) }
                }
                .tint(Theme.berry)
            } else {
                OnboardingView()
            }
        }
        // A tap on a notification body sets `openedBlock` even on a cold launch, before this
        // view subscribes — `initial: true` re-checks the current value so that case still
        // switches to Today, and TodayView (also `initial: true`) still presents the sheet.
        .onChange(of: notifications.openedBlock, initial: true) { _, payload in
            if payload != nil { tab = 0 }
        }
    }
}
