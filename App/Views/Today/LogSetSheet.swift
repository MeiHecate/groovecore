import SwiftUI

struct LogSetSheet: View {
    @Environment(GrooveStore.self) private var store
    let row: TodayModel.Row
    let onLogged: (UUID) -> Void
    @State private var reps = 1
    @State private var taps = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(row.exercise.displayName()).font(.title2.weight(.bold)).foregroundStyle(Theme.chalk)
                Text(verbatim: "\(reps)").font(Theme.counter(72)).foregroundStyle(Theme.chalk)
                Stepper("", value: $reps, in: 1...999).labelsHidden()
                    .accessibilityLabel(tr("logSet.title"))
                    .onChange(of: reps) { _, _ in taps += 1 }
                Button {
                    let setId = store.logSet(exerciseId: row.exercise.id, reps: reps, at: .now)
                    onLogged(setId)
                } label: {
                    Text(tr("action.log")).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Theme.berry, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(Theme.onBerry)
                }
            }
            .padding(24)
            .navigationTitle(tr("logSet.title"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: taps)
        .presentationDetents([.medium])
        .onAppear { reps = row.program.workingReps }
    }
}
