import SwiftUI
import GrooveKit

/// Opened from a notification tap or the next-block card: reps editable per exercise before logging.
struct BlockDetailView: View {
    @Environment(GrooveStore.self) private var store
    let payload: BlockPayload
    let onFinish: (String?) -> Void
    @State private var reps: [Int] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(payload.items.enumerated()), id: \.offset) { index, item in
                    if let exercise = store.exercise(id: item.exerciseId), !exercise.isArchived {
                        Stepper(value: binding(index), in: 1...999) {
                            HStack {
                                Text(exercise.displayName())
                                Spacer()
                                Text(verbatim: "\(reps.indices.contains(index) ? reps[index] : item.reps)")
                                    .font(Theme.counter(20))
                            }
                        }
                    }
                }
            }
            .navigationTitle(NotificationText.title(for: blockDate, locale: .current))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("action.skip")) {
                        store.skipBlock(payload, at: .now)
                        AppEnvironment.shared.dataChanged()
                        onFinish(nil)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("action.done")) {
                        let items = zip(payload.items, reps).map { PlannedItem(exerciseId: $0.exerciseId, reps: $1) }
                        let logged = store.logBlock(BlockPayload(blockId: payload.blockId, items: items), at: .now)
                        onFinish(logged ? payload.blockId : nil)
                    }
                    .bold()
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear { reps = payload.items.map(\.reps) }
    }

    private var blockDate: Date {
        // blockId is yyyy-MM-dd-HHmm in local time
        let parts = payload.blockId.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 4 else { return .now }
        return store.calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2],
                                                        hour: parts[3] / 100, minute: parts[3] % 100)) ?? .now
    }

    private func binding(_ index: Int) -> Binding<Int> {
        Binding(get: { reps.indices.contains(index) ? reps[index] : 1 },
                set: { if reps.indices.contains(index) { reps[index] = $0 } })
    }
}
