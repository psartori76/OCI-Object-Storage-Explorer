import SwiftUI

enum AppShadows {
    static func card(for scheme: ColorScheme) -> (color: Color, radius: CGFloat, y: CGFloat) {
        switch scheme {
        case .dark:
            return (Color.black.opacity(0.28), 16, 6)
        default:
            return (Color.black.opacity(0.08), 12, 4)
        }
    }

    static let softGlowBlue = Color(hex: "#60A5FA", opacity: 0.18)
}
