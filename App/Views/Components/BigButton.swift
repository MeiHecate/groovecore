import SwiftUI

struct BigButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Theme.berry, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(Theme.onBerry)
        }
    }
}
