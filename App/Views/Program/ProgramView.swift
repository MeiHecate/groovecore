import SwiftUI

struct ProgramView: View {
    @Environment(GrooveStore.self) private var store
    @State private var showLibrary = false

    var body: some View {
        let _ = store.revision
        let all = store.programs(activeOnly: false)
        let active = all.filter(\.isActive)
        let paused = all.filter { !$0.isActive && store.exercise(id: $0.exerciseId)?.isArchived == false }
        NavigationStack {
            List {
                Section {
                    ForEach(active) { row($0) }
                        .onMove { from, to in
                            store.moveActivePrograms(from: from, to: to)
                            AppEnvironment.shared.dataChanged()
                        }
                }
                if !paused.isEmpty {
                    Section(tr("program.paused")) { ForEach(paused) { row($0) } }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.ground)
            .navigationTitle(tr("tab.program"))
            .navigationDestination(for: UUID.self) { ExerciseDetailView(programId: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(tr("program.add")) { showLibrary = true }
                }
            }
            .sheet(isPresented: $showLibrary) { LibraryView() }
        }
    }

    private func row(_ program: Program) -> some View {
        let exercise = store.exercise(id: program.exerciseId)
        let detail = exercise?.unit == .seconds
            ? tr("program.rowSeconds", program.workingReps, program.dailySets)
            : tr("program.row", program.workingReps, program.dailySets)
        return NavigationLink(value: program.id) {
            HStack {
                Text(exercise?.displayName() ?? "").foregroundStyle(program.isActive ? Theme.chalk : Theme.chalk3)
                Spacer()
                Text(detail).font(.subheadline).monospacedDigit().foregroundStyle(Theme.chalk3)
            }
        }
        .swipeActions {
            Button(program.isActive ? tr("program.pause") : tr("program.resume")) {
                store.setActive(program, !program.isActive)
                AppEnvironment.shared.dataChanged()
            }
            .tint(program.isActive ? Theme.chalk3 : Theme.mint)
        }
    }
}
