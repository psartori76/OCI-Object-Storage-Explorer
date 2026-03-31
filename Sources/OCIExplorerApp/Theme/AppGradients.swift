import SwiftUI

enum AppGradients {
    static let brandHeroGradient = LinearGradient(
        colors: [
            BrandColors.brandBlueDeep,
            BrandColors.brandBluePrimary,
            BrandColors.brandBlueLight
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let brandSelectionGradient = LinearGradient(
        colors: [
            BrandColors.brandBluePrimary,
            BrandColors.brandBlueBright
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let brandAccentGlow = LinearGradient(
        colors: [
            BrandColors.brandOrangeAccent,
            BrandColors.brandOrangeSoft
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
