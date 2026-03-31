import SwiftUI

enum BrandColors {
    static let brandBlueDeep = Color(hex: "#0B1F6D")
    static let brandBluePrimary = Color(hex: "#2563EB")
    static let brandBlueBright = Color(hex: "#3B82F6")
    static let brandBlueLight = Color(hex: "#60A5FA")
    static let brandCyanSoft = Color(hex: "#7DD3FC")

    static let brandOrangeAccent = Color(hex: "#F97316")
    static let brandOrangeSoft = Color(hex: "#FB923C")

    static let surfaceBaseLight = Color(hex: "#F7F9FC")
    static let surfaceCardLight = Color(hex: "#FFFFFF")
    static let surfaceElevatedLight = Color(hex: "#EEF4FF")
    static let borderSubtleLight = Color(hex: "#D9E2F2")
    static let borderStrongLight = Color(hex: "#B8C7E6")
    static let textPrimaryLight = Color(hex: "#0F172A")
    static let textSecondaryLight = Color(hex: "#475569")
    static let textTertiaryLight = Color(hex: "#64748B")

    static let surfaceBaseDark = Color(hex: "#081226")
    static let surfaceCardDark = Color(hex: "#0F1B34")
    static let surfaceElevatedDark = Color(hex: "#132445")
    static let borderSubtleDark = Color(hex: "#22365F")
    static let borderStrongDark = Color(hex: "#31508B")
    static let textPrimaryDark = Color(hex: "#EAF2FF")
    static let textSecondaryDark = Color(hex: "#B8C7E6")
    static let textTertiaryDark = Color(hex: "#8EA3C7")

    static let success = Color(hex: "#16A34A")
    static let warning = Color(hex: "#F59E0B")
    static let error = Color(hex: "#DC2626")
    static let info = Color(hex: "#2563EB")

    static let selectionBlueLight = Color(hex: "#DCEAFE")
    static let selectionBlueDark = Color(hex: "#1D4ED8")
    static let focusRingBlue = Color(hex: "#60A5FA")

    static let sidebarBackgroundLight = Color(hex: "#F3F6FB")
    static let sidebarBackgroundDark = Color(hex: "#0B152B")
    static let sidebarHoverLight = Color(hex: "#EAF2FF")
    static let sidebarHoverDark = Color(hex: "#132445")
    static let sidebarSelectedLight = Color(hex: "#DCEAFE")
    static let sidebarSelectedDark = Color(hex: "#163A8A")
    static let sidebarSelectedBorderLight = Color(hex: "#BFDBFE")
    static let sidebarSelectedBorderDark = Color(hex: "#3B82F6")

    static let toolbarIconLight = Color(hex: "#334155")
    static let toolbarIconDark = Color(hex: "#D6E4FF")
    static let toolbarHoverLight = Color(hex: "#EAF2FF")
    static let toolbarHoverDark = Color(hex: "#132445")
    static let toolbarActiveLight = Color(hex: "#DBEAFE")
    static let toolbarActiveDark = Color(hex: "#1D4ED8")

    static let tableHeaderLight = Color(hex: "#F8FBFF")
    static let tableHeaderDark = Color(hex: "#0F1B34")
    static let tableHeaderTextLight = Color(hex: "#475569")
    static let tableHeaderTextDark = Color(hex: "#B8C7E6")
    static let tableSeparatorLight = Color(hex: "#E2E8F0")
    static let tableSeparatorDark = Color(hex: "#22365F")
    static let tableHoverLight = Color(hex: "#F1F7FF")
    static let tableHoverDark = Color(hex: "#12213F")
    static let tableSelectedLight = Color(hex: "#DBEAFE")
    static let tableSelectedDark = Color(hex: "#1D4ED8")
    static let tableSelectedBorderLight = Color(hex: "#93C5FD")
    static let tableSelectedBorderDark = Color(hex: "#60A5FA")

    static let inspectorBackgroundLight = Color(hex: "#EDF3FB")
    static let inspectorBackgroundDark = Color(hex: "#0B152B")

    static let destructiveBackgroundLight = Color(hex: "#FEF2F2")
    static let destructiveBackgroundDark = Color(hex: "#3A1414")

    static let successToastLight = Color(hex: "#ECFDF5")
    static let successToastDark = Color(hex: "#052E1B")
    static let successToastText = Color(hex: "#166534")
    static let errorToastLight = Color(hex: "#FEF2F2")
    static let errorToastDark = Color(hex: "#3A1010")
    static let errorToastText = Color(hex: "#B91C1C")
    static let warningToastLight = Color(hex: "#FFFBEB")
    static let warningToastDark = Color(hex: "#3B2A08")
    static let warningToastText = Color(hex: "#B45309")
    static let infoToastLight = Color(hex: "#EFF6FF")
    static let infoToastDark = Color(hex: "#0E2A52")
}

extension Color {
    init(hex: String, opacity: Double = 1) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: (Double(a) / 255) * opacity
        )
    }
}
