import SwiftUI
import UIKit

enum Theme {
    static let ground = dynamic(light: 0xF3F2EF, dark: 0x0E0F10)
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x1C1D1E)
    static let raised = dynamic(light: 0xE9E7E2, dark: 0x27282A)
    static let line = dynamic(light: 0xDDDAD4, dark: 0x333436)
    static let chalk = dynamic(light: 0x1C1B19, dark: 0xEDEAE3)
    static let chalk2 = dynamic(light: 0x55524D, dark: 0xA9A6A0)
    static let chalk3 = dynamic(light: 0x8A8680, dark: 0x6F6D69)
    static let berry = dynamic(light: 0xD42A50, dark: 0xFF4D6D)
    static let onBerry = dynamic(light: 0xFFFFFF, dark: 0x24070E)
    static let mint = dynamic(light: 0x1F9D63, dark: 0x5FD39A)
    static let amber = dynamic(light: 0xA86A12, dark: 0xF5B83D)
    static let tallyTodo = dynamic(light: 0xC9C5BE, dark: 0x4A4B4D)

    static func counter(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy).monospacedDigit()
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

extension View {
    /// Flat card: surface fill, radius 16, no shadow.
    func card() -> some View {
        padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
