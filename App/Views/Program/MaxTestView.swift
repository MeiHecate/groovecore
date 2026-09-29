import SwiftUI
import GrooveKit

/// Full screen: tap anywhere to count reps, or a stopwatch for exercises in seconds.
struct MaxTestView: View {
    let exercise: Exercise
    let onFinish: (Int?) -> Void

    @State private var count = 0
    @State private var startedAt: Date?
    @State private var elapsed = 0

    private var result: Int { exercise.unit == .reps ? count : elapsed }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button(tr("action.cancel")) { onFinish(nil) }
                Spacer()
            }
            Text(exercise.displayName()).font(.title2.weight(.bold)).foregroundStyle(Theme.chalk)
            if exercise.unit == .reps { repsCounter } else { stopwatch }
            BigButton(title: tr("maxTest.finish")) { onFinish(result) }
                .disabled(result == 0 || startedAt != nil)
                .opacity(result == 0 || startedAt != nil ? 0.4 : 1)
        }
        .padding(24)
        .background(Theme.ground)
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: count)
    }

    private var repsCounter: some View {
        VStack(spacing: 12) {
            Text(verbatim: "\(count)").font(Theme.counter(120)).foregroundStyle(Theme.chalk)
                .accessibilityLabel(tr("maxTest.tapHint"))
                .accessibilityValue(Text(verbatim: "\(count)"))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { count += 1 }
            Text(tr("maxTest.tapHint")).font(.subheadline).foregroundStyle(Theme.chalk3)
            Button { count = max(0, count - 1) } label: {
                Image(systemName: "minus.circle").font(.title)
            }
            .foregroundStyle(Theme.chalk2)
            .accessibilityLabel(tr("maxTest.minusOne"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { count += 1 }
    }

    private var stopwatch: some View {
        VStack(spacing: 20) {
            TimelineView(.periodic(from: .now, by: 0.2)) { context in
                let seconds = startedAt.map { Int(context.date.timeIntervalSince($0).rounded()) } ?? elapsed
                Text(tr("maxTest.seconds", seconds)).font(Theme.counter(96)).foregroundStyle(Theme.chalk)
            }
            Button {
                if let startedAt {
                    elapsed = Int(Date().timeIntervalSince(startedAt).rounded())
                    self.startedAt = nil
                } else {
                    elapsed = 0
                    startedAt = .now
                }
            } label: {
                Text(startedAt == nil ? tr("maxTest.start") : tr("maxTest.stop"))
                    .font(.headline).padding(.vertical, 12).padding(.horizontal, 32)
                    .background(Theme.raised, in: Capsule()).foregroundStyle(Theme.chalk)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
