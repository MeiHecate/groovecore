import Charts
import SwiftUI
import GrooveKit

struct ExerciseDetailView: View {
    @Environment(GrooveStore.self) private var store
    let programId: UUID

    @State private var testing = false
    @State private var confirmation: ProgramRules.RetestOutcome?

    var body: some View {
        let _ = store.revision
        if let program = store.programs(activeOnly: false).first(where: { $0.id == programId }),
           let exercise = store.exercise(id: program.exerciseId) {
            content(program, exercise)
        }
    }

    private func content(_ program: Program, _ exercise: Exercise) -> some View {
        let tests = store.maxTests(exerciseId: exercise.id)
        let next = ProgramRules.nextRetestDay(lastTestDay: LocalDay(program.lastTestDate, calendar: store.calendar),
                                              intervalDays: program.retestIntervalDays, calendar: store.calendar)
        return ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    StatTile(label: tr("detail.max"), value: statValue(program.maxValue, exercise))
                    StatTile(label: tr("detail.work"), value: tr("detail.percentValue", program.workPercent))
                    StatTile(label: tr("detail.reps"), value: statValue(program.workingReps, exercise), accent: true)
                }
                if !tests.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(tr("detail.history")).font(.caption).foregroundStyle(Theme.chalk3)
                        Chart(tests) { test in
                            AreaMark(x: .value(tr("detail.history"), test.date), y: .value(tr("detail.max"), test.value))
                                .foregroundStyle(Theme.chalk.opacity(0.08))
                            LineMark(x: .value(tr("detail.history"), test.date), y: .value(tr("detail.max"), test.value))
                                .foregroundStyle(Theme.chalk2)
                            PointMark(x: .value(tr("detail.history"), test.date), y: .value(tr("detail.max"), test.value))
                                .foregroundStyle(Theme.chalk)
                        }
                        .chartYScale(domain: 0...max(1, (tests.map(\.value).max() ?? 1) * 6 / 5))
                        .frame(height: 140)
                    }
                    .card()
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text(tr("detail.nextRetest", next.date(calendar: store.calendar).formatted(date: .abbreviated, time: .omitted)))
                        .font(.subheadline).foregroundStyle(Theme.chalk)
                    Button(tr("detail.retest")) { testing = true }.font(.subheadline.weight(.semibold))
                }
                .card()
                VStack(spacing: 12) {
                    Stepper(tr("detail.workPercent", program.workPercent),
                            value: binding(program, \.workPercent), in: 10...90, step: 5)
                        .disabled(program.manualReps != nil)
                    Toggle(tr("detail.manualReps"), isOn: Binding(
                        get: { program.manualReps != nil },
                        set: { on in
                            store.update(program) { $0.manualReps = on ? $0.workingReps : nil }
                            AppEnvironment.shared.dataChanged()
                        }))
                    if program.manualReps != nil {
                        Stepper(tr("detail.repsValue", program.workingReps), value: Binding(
                            get: { program.manualReps ?? program.workingReps },
                            set: { value in
                                store.update(program) { $0.manualReps = value }
                                AppEnvironment.shared.dataChanged()
                            }), in: 1...999)
                    }
                    Stepper(tr("detail.dailySets", program.dailySets), value: binding(program, \.dailySets), in: 1...30)
                    Stepper(tr("detail.retestEvery", program.retestIntervalDays),
                            value: binding(program, \.retestIntervalDays), in: 3...60)
                }
                .foregroundStyle(Theme.chalk)
                .card()
            }
            .padding(16)
        }
        .background(Theme.ground)
        .navigationTitle(exercise.displayName())
        .fullScreenCover(isPresented: $testing) {
            MaxTestView(exercise: exercise) { result in
                testing = false
                guard let result else { return }
                let outcome = store.recordMaxTest(program, value: result)
                if case .needsConfirmation = outcome { confirmation = outcome }
                AppEnvironment.shared.dataChanged()
            }
        }
        .confirmationDialog(tr("retest.title", program.maxValue),
                            isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } }),
                            titleVisibility: .visible) {
            if case .needsConfirmation(let manual, let recalculated) = confirmation {
                Button(tr("retest.keep", manual)) {}
                Button(tr("retest.recalc", recalculated)) {
                    store.useRecalculatedReps(program)
                    AppEnvironment.shared.dataChanged()
                }
            }
        }
    }

    private func statValue(_ n: Int, _ exercise: Exercise) -> String {
        exercise.unit == .seconds ? tr("maxTest.seconds", n) : "\(n)"
    }

    private func binding(_ program: Program, _ keyPath: ReferenceWritableKeyPath<Program, Int>) -> Binding<Int> {
        Binding(get: { program[keyPath: keyPath] },
                set: { value in
                    store.update(program) { $0[keyPath: keyPath] = value }
                    AppEnvironment.shared.dataChanged()
                })
    }
}
