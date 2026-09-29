import SwiftUI
import GrooveKit

struct OnboardingView: View {
    @Environment(GrooveStore.self) private var store
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(NotificationCoordinator.self) private var notifications

    @State private var step = 0
    @State private var selected: [UUID] = []
    @State private var maxes: [UUID: Int] = [:]
    @State private var creating = false
    @State private var testing: Exercise?

    private let titles = ["onb.step1.title", "onb.step2.title", "onb.step3.title"]
    private let bodies = ["onb.step1.body", "onb.step2.body", "onb.step3.body"]

    var body: some View {
        let _ = store.revision
        VStack(alignment: .leading, spacing: 14) {
            Text(tr(titles[step])).font(.system(size: 30, weight: .heavy)).foregroundStyle(Theme.chalk)
            Text(tr(bodies[step])).foregroundStyle(Theme.chalk2)
            Group {
                switch step {
                case 0: pickStep
                case 1: maxStep
                default: dayStep
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            if step > 0 {
                Button(tr("onb.back")) { step -= 1 }.foregroundStyle(Theme.chalk2)
            }
            BigButton(title: step < 2 ? tr("onb.next") : tr("onb.finish"), action: next)
                .disabled(selected.isEmpty)
                .opacity(selected.isEmpty ? 0.4 : 1)
        }
        .padding(20)
        .background(Theme.ground)
        .sheet(isPresented: $creating) { ExerciseEditorView(exercise: nil) }
        .fullScreenCover(item: $testing) { exercise in
            MaxTestView(exercise: exercise) { result in
                if let result { maxes[exercise.id] = result }
                testing = nil
            }
        }
    }

    // The keys above are listed here so check-l10n.py sees them:
    // tr("onb.step1.title") tr("onb.step2.title") tr("onb.step3.title")
    // tr("onb.step1.body") tr("onb.step2.body") tr("onb.step3.body")

    private var pickStep: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(store.exercises()) { exercise in
                    let on = selected.contains(exercise.id)
                    Button {
                        if on { selected.removeAll { $0 == exercise.id } } else { selected.append(exercise.id) }
                    } label: {
                        HStack {
                            Text(exercise.displayName()).foregroundStyle(Theme.chalk)
                            Spacer()
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(on ? Theme.chalk : Theme.chalk3)
                                .accessibilityHidden(true)
                        }
                        .padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(exercise.displayName())
                    .accessibilityAddTraits(on ? .isSelected : [])
                    Divider().overlay(Theme.line)
                }
                Button(tr("library.new")) { creating = true }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
            }
        }
    }

    private var maxStep: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(selected, id: \.self) { id in
                    if let exercise = store.exercise(id: id) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercise.displayName()).foregroundStyle(Theme.chalk)
                                Button(tr("maxEntry.test")) { testing = exercise }.font(.caption.weight(.semibold))
                            }
                            Spacer()
                            Text(verbatim: "\(maxes[id] ?? 5)").font(Theme.counter(24)).foregroundStyle(Theme.chalk)
                            Stepper("", value: Binding(get: { maxes[id] ?? 5 }, set: { maxes[id] = $0 }), in: 1...999)
                                .labelsHidden()
                                .accessibilityLabel(exercise.displayName())
                        }
                        .card()
                    }
                }
            }
        }
    }

    private var dayStep: some View {
        let s = settingsStore.settings
        let scheduled = selected.map {
            ScheduleExercise(id: $0, order: 0, dailySets: 8,
                             reps: ProgramRules.workingReps(maxValue: maxes[$0] ?? 5, workPercent: s.defaultWorkPercent, manualReps: nil))
        }
        let overflow = ScheduleBuilder.capacityOverflow(exercises: scheduled, settings: s,
                                                        referenceDay: LocalDay(.now, calendar: store.calendar), calendar: store.calendar)
        return VStack(alignment: .leading, spacing: 12) {
            MinutesPicker(title: tr("settings.start"), minutes: s.windowStartMinutes) { settingsStore.settings.setWindowStart($0) }
            MinutesPicker(title: tr("settings.end"), minutes: s.windowEndMinutes) { settingsStore.settings.setWindowEnd($0) }
            Text(tr("settings.restDays")).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.chalk)
            WeekdayToggles(selection: s.restWeekdays) { weekday in
                if settingsStore.settings.restWeekdays.contains(weekday) {
                    settingsStore.settings.restWeekdays.remove(weekday)
                } else {
                    settingsStore.settings.restWeekdays.insert(weekday)
                }
            }
            Text(overflow > 0 ? tr("settings.overflow", overflow) : tr("settings.overflowOk"))
                .font(.subheadline)
                .foregroundStyle(overflow > 0 ? Theme.amber : Theme.mint)
        }
        .foregroundStyle(Theme.chalk)
        .card()
    }

    private func next() {
        guard step == 2 else { step += 1; return }
        for id in selected {
            if let exercise = store.exercise(id: id) {
                store.activate(exercise, maxValue: maxes[id] ?? 5, settings: settingsStore.settings)
            }
        }
        settingsStore.hasOnboarded = true
        Task {
            await notifications.requestAuthorization()
            await notifications.reschedule()
        }
    }
}
