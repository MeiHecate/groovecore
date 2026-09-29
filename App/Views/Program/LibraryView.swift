import SwiftUI

struct LibraryView: View {
    @Environment(GrooveStore.self) private var store
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var adding: Exercise?
    @State private var editing: Exercise?
    @State private var creating = false
    @State private var deleting: Exercise?

    var body: some View {
        let _ = store.revision
        let exercises = store.exercises()
        NavigationStack {
            List {
                Section(tr("library.builtin")) {
                    ForEach(exercises.filter { !$0.isCustom }) { row($0) }
                }
                Section(tr("library.custom")) {
                    ForEach(exercises.filter(\.isCustom)) { exercise in
                        row(exercise)
                            .swipeActions {
                                Button(tr("library.delete"), role: .destructive) { deleting = exercise }
                                Button(tr("library.edit")) { editing = exercise }
                            }
                    }
                    Button(tr("library.new")) { creating = true }
                }
            }
            .navigationTitle(tr("library.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(tr("action.close")) { dismiss() } }
            }
            .sheet(item: $adding) { exercise in
                MaxEntrySheet(exercise: exercise) { value in
                    store.activate(exercise, maxValue: value, settings: settingsStore.settings)
                    AppEnvironment.shared.dataChanged()
                }
            }
            .sheet(isPresented: $creating) { ExerciseEditorView(exercise: nil) }
            .sheet(item: $editing) { ExerciseEditorView(exercise: $0) }
            .confirmationDialog(tr("library.deleteConfirm", deleting?.displayName() ?? ""),
                                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                                titleVisibility: .visible, presenting: deleting) { exercise in
                Button(tr("library.delete"), role: .destructive) {
                    _ = store.deleteOrArchive(exercise)
                    AppEnvironment.shared.dataChanged()
                }
            } message: { exercise in
                Text(store.hasHistory(exercise) ? tr("library.archiveNote") : tr("library.deleteNote"))
            }
        }
    }

    private func row(_ exercise: Exercise) -> some View {
        let program = store.program(exerciseId: exercise.id)
        let isActive = program?.isActive == true
        return HStack {
            Text(exercise.displayName()).foregroundStyle(Theme.chalk)
            if exercise.perSide { Text(tr("unit.perSide")).foregroundStyle(Theme.chalk3) }
            if exercise.unit == .seconds { Text(tr("unit.seconds")).foregroundStyle(Theme.chalk3) }
            Spacer()
            if isActive {
                Text(tr("library.active")).font(.caption.weight(.semibold)).foregroundStyle(Theme.mint)
            } else {
                Image(systemName: "plus.circle").foregroundStyle(Theme.chalk3)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isActive else { return }
            if let program {
                // Paused, existing program: resume it as-is instead of resetting its max via MaxEntrySheet.
                store.setActive(program, true)
                AppEnvironment.shared.dataChanged()
            } else {
                adding = exercise
            }
        }
    }
}
