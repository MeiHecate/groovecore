import SwiftUI

struct UndoBanner: View {
    let message: String
    let onUndo: () -> Void
    let onTimeout: () -> Void

    var body: some View {
        HStack {
            Text(message).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.chalk)
            Spacer()
            Button(tr("action.undo"), action: onUndo)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.berry)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
        .task {
            try? await Task.sleep(for: .seconds(5))
            onTimeout()
        }
    }
}
