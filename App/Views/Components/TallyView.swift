import SwiftUI

/// One stroke per set, the fifth crosses the four before it. Solid = done, dashed = to do.
/// `done` is a Double so the newest stroke can draw itself (animatableData).
struct TallyView: View, Animatable {
    var done: Double
    let goal: Int

    var animatableData: Double {
        get { done }
        set { done = newValue }
    }

    private let step: CGFloat = 6
    private let gap: CGFloat = 10
    private let height: CGFloat = 20

    var body: some View {
        Canvas { context, _ in
            var x: CGFloat = 0
            var index = 0
            for group in 0..<groupCount {
                let count = min(5, goal - group * 5)
                let groupX = x
                for _ in 0..<min(4, count) {
                    var line = Path()
                    line.move(to: CGPoint(x: x + 3, y: 3))
                    line.addLine(to: CGPoint(x: x + 3, y: height - 1))
                    draw(line, index: index, in: context)
                    index += 1
                    x += step
                }
                if count == 5 {
                    var slash = Path()
                    slash.move(to: CGPoint(x: groupX - 1, y: height - 4))
                    slash.addLine(to: CGPoint(x: groupX + 4 * step + 1, y: 6))
                    draw(slash, index: index, in: context)
                    index += 1
                }
                x += gap
            }
        }
        .frame(width: width, height: height + 2)
        .accessibilityElement()
        .accessibilityLabel(tr("tally.a11y", Int(done.rounded()), goal))
    }

    private var groupCount: Int { (goal + 4) / 5 }

    private var width: CGFloat {
        var total: CGFloat = 0
        for group in 0..<groupCount { total += CGFloat(min(4, goal - group * 5)) * step + gap }
        return max(total, 1)
    }

    private func draw(_ path: Path, index: Int, in context: GraphicsContext) {
        context.stroke(path, with: .color(Theme.tallyTodo),
                       style: StrokeStyle(lineWidth: 2.4, lineCap: .round, dash: [2, 3]))
        let fraction = min(max(done - Double(index), 0), 1)
        guard fraction > 0 else { return }
        context.stroke(path.trimmedPath(from: 0, to: fraction), with: .color(Theme.chalk),
                       style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
    }
}
