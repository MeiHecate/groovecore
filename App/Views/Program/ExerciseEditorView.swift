import SwiftUI
import GrooveKit

extension ExerciseNameError {
    var message: String {
        switch self {
        case .empty: return tr("editor.error.empty")
        case .tooLong: return tr("editor.error.tooLong")
        case .duplicate: return tr("editor.error.duplicate")
        }
    }
}

struct ExerciseEditorView: View {
    @Environment(GrooveStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let exercise: Exercise?

    @State private var name = ""
    @State private var unit: ExerciseUnit = .reps
    @State private var perSide = false
    @State private var error: String?

    private var unitEditable: Bool { exercise.map { store.canChangeUnit($0) } ?? true }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(tr("editor.name"), text: $name)
                        .textInputAutocapitalization(.sentences)
                    if let error {
                        Text(error).font(.footnote).foregroundStyle(Theme.amber)
                    }
                }
                Section {
                    Picker(tr("editor.unit"), selection: $unit) {
                        Text(tr("unit.repsLong")).tag(ExerciseUnit.reps)
                        Text(tr("unit.secondsLong")).tag(ExerciseUnit.seconds)
                    }
                    .disabled(!unitEditable)
                    Toggle(tr("editor.perSide"), isOn: $perSide)
                } footer: {
                    if !unitEditable { Text(tr("editor.unitLocked")) }
                }
            }
            .navigationTitle(exercise == nil ? tr("library.new") : tr("editor.editTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(tr("action.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(tr("action.save"), action: save).bold() }
            }
        }
        .onAppear {
            guard let exercise else { return }
            name = exercise.customName ?? ""
            unit = exercise.unit
            perSide = exercise.perSide
        }
    }

    private func save() {
        do {
            if let exercise {
                try store.updateCustomExercise(exercise, name: name, unit: unit, perSide: perSide)
            } else {
                try store.createCustomExercise(name: name, unit: unit, perSide: perSide)
            }
            AppEnvironment.shared.dataChanged()
            dismiss()
        } catch let nameError as ExerciseNameError {
            error = nameError.message
        } catch {
            self.error = tr("editor.error.empty")
        }
    }
}
