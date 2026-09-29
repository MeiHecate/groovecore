import SwiftUI

struct MaxEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    let exercise: Exercise
    let onConfirm: (Int) -> Void

    @State private var value = 5
    @State private var testing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(exercise.unit == .seconds ? tr("maxEntry.promptSeconds") : tr("maxEntry.prompt"))
                    .multilineTextAlignment(.center).foregroundStyle(Theme.chalk2)
                Text(verbatim: "\(value)").font(Theme.counter(72)).foregroundStyle(Theme.chalk)
                Stepper("", value: $value, in: 1...999).labelsHidden()
                    .accessibilityLabel(exercise.displayName())
                Button(tr("maxEntry.test")) { testing = true }.font(.subheadline.weight(.semibold))
                BigButton(title: tr("maxEntry.add")) {
                    onConfirm(value)
                    dismiss()
                }
            }
            .padding(24)
            .navigationTitle(exercise.displayName())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(tr("action.cancel")) { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .fullScreenCover(isPresented: $testing) {
            MaxTestView(exercise: exercise) { result in
                testing = false
                if let result { value = result }
            }
        }
    }
}
