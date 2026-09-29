import SwiftUI
import GrooveKit

struct SettingsView: View {
    @Environment(GrooveStore.self) private var store
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(NotificationCoordinator.self) private var notifications

    var body: some View {
        let _ = store.revision
        @Bindable var bindable = settingsStore
        let s = settingsStore.settings
        let overflow = ScheduleBuilder.capacityOverflow(
            exercises: store.scheduleInput(now: .now, settings: s).exercises, settings: s,
            referenceDay: LocalDay(.now, calendar: store.calendar), calendar: store.calendar)
        NavigationStack {
            Form {
                Section(tr("settings.window")) {
                    MinutesPicker(title: tr("settings.start"), minutes: s.windowStartMinutes) { settingsStore.settings.setWindowStart($0) }
                    MinutesPicker(title: tr("settings.end"), minutes: s.windowEndMinutes) { settingsStore.settings.setWindowEnd($0) }
                    Stepper(tr("settings.interval", s.effectiveInterval),
                            value: $bindable.settings.intervalMinutes, in: GrooveSettings.minimumInterval...180, step: 5)
                    Stepper(tr("settings.blockSize", s.maxBlockSize), value: $bindable.settings.maxBlockSize, in: 1...6)
                }
                Section {
                    Text(overflow > 0 ? tr("settings.overflow", overflow) : tr("settings.overflowOk"))
                        .font(.subheadline)
                        .foregroundStyle(overflow > 0 ? Theme.amber : Theme.mint)
                }
                Section(tr("settings.restDays")) {
                    WeekdayToggles(selection: s.restWeekdays) { weekday in
                        if settingsStore.settings.restWeekdays.contains(weekday) {
                            settingsStore.settings.restWeekdays.remove(weekday)
                        } else {
                            settingsStore.settings.restWeekdays.insert(weekday)
                        }
                    }
                }
                Section(tr("settings.program")) {
                    Stepper(tr("settings.defaultPercent", s.defaultWorkPercent),
                            value: $bindable.settings.defaultWorkPercent, in: 10...90, step: 5)
                    Toggle(tr("settings.sound"), isOn: $bindable.settings.soundEnabled)
                }
                Section(tr("settings.notifications")) {
                    HStack {
                        Text(notifications.isAuthorized ? tr("settings.notif.on") : tr("settings.notif.off"))
                            .foregroundStyle(notifications.isAuthorized ? Theme.mint : Theme.chalk2)
                        Spacer()
                        if notifications.authorization == .notDetermined {
                            Button(tr("settings.notif.ask")) {
                                Task {
                                    await notifications.requestAuthorization()
                                    await notifications.reschedule()
                                }
                            }
                        } else if !notifications.isAuthorized {
                            Button(tr("today.openSettings")) {
                                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.ground)
            .navigationTitle(tr("tab.settings"))
        }
        .task { await notifications.refreshAuthorization() }
    }
}
