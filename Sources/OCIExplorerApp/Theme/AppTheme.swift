import SwiftUI

struct AppThemePalette {
    let appBackground: Color
    let cardBackground: Color
    let elevatedBackground: Color
    let borderSubtle: Color
    let borderStrong: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let selectionFill: Color
    let selectionBorder: Color
    let focusRing: Color
    let sidebarBackground: Color
    let sidebarHover: Color
    let sidebarSelected: Color
    let sidebarSelectedBorder: Color
    let toolbarBackground: Color
    let toolbarIcon: Color
    let toolbarHover: Color
    let toolbarActive: Color
    let tableHeaderBackground: Color
    let tableHeaderText: Color
    let tableSeparator: Color
    let tableHover: Color
    let tableSelected: Color
    let tableSelectedBorder: Color
    let inspectorBackground: Color
    let searchBackground: Color
}

enum AppTheme {
    static func current(for scheme: ColorScheme) -> AppThemePalette {
        switch scheme {
        case .dark:
            return AppThemePalette(
                appBackground: BrandColors.surfaceBaseDark,
                cardBackground: BrandColors.surfaceCardDark,
                elevatedBackground: BrandColors.surfaceElevatedDark,
                borderSubtle: BrandColors.borderSubtleDark,
                borderStrong: BrandColors.borderStrongDark,
                textPrimary: BrandColors.textPrimaryDark,
                textSecondary: BrandColors.textSecondaryDark,
                textTertiary: BrandColors.textTertiaryDark,
                selectionFill: BrandColors.selectionBlueDark,
                selectionBorder: BrandColors.focusRingBlue,
                focusRing: BrandColors.focusRingBlue,
                sidebarBackground: BrandColors.sidebarBackgroundDark,
                sidebarHover: BrandColors.sidebarHoverDark,
                sidebarSelected: BrandColors.sidebarSelectedDark,
                sidebarSelectedBorder: BrandColors.sidebarSelectedBorderDark,
                toolbarBackground: BrandColors.surfaceCardDark.opacity(0.88),
                toolbarIcon: BrandColors.toolbarIconDark,
                toolbarHover: BrandColors.toolbarHoverDark,
                toolbarActive: BrandColors.toolbarActiveDark,
                tableHeaderBackground: BrandColors.tableHeaderDark,
                tableHeaderText: BrandColors.tableHeaderTextDark,
                tableSeparator: BrandColors.tableSeparatorDark,
                tableHover: BrandColors.tableHoverDark,
                tableSelected: BrandColors.tableSelectedDark,
                tableSelectedBorder: BrandColors.tableSelectedBorderDark,
                inspectorBackground: BrandColors.inspectorBackgroundDark,
                searchBackground: BrandColors.surfaceElevatedDark
            )
        default:
            return AppThemePalette(
                appBackground: BrandColors.surfaceBaseLight,
                cardBackground: BrandColors.surfaceCardLight,
                elevatedBackground: BrandColors.surfaceElevatedLight,
                borderSubtle: BrandColors.borderSubtleLight,
                borderStrong: BrandColors.borderStrongLight,
                textPrimary: BrandColors.textPrimaryLight,
                textSecondary: BrandColors.textSecondaryLight,
                textTertiary: BrandColors.textTertiaryLight,
                selectionFill: BrandColors.selectionBlueLight,
                selectionBorder: BrandColors.tableSelectedBorderLight,
                focusRing: BrandColors.focusRingBlue,
                sidebarBackground: BrandColors.sidebarBackgroundLight,
                sidebarHover: BrandColors.sidebarHoverLight,
                sidebarSelected: BrandColors.sidebarSelectedLight,
                sidebarSelectedBorder: BrandColors.sidebarSelectedBorderLight,
                toolbarBackground: Color.white.opacity(0.88),
                toolbarIcon: BrandColors.toolbarIconLight,
                toolbarHover: BrandColors.toolbarHoverLight,
                toolbarActive: BrandColors.toolbarActiveLight,
                tableHeaderBackground: BrandColors.tableHeaderLight,
                tableHeaderText: BrandColors.tableHeaderTextLight,
                tableSeparator: BrandColors.tableSeparatorLight,
                tableHover: BrandColors.tableHoverLight,
                tableSelected: BrandColors.tableSelectedLight,
                tableSelectedBorder: BrandColors.tableSelectedBorderLight,
                inspectorBackground: BrandColors.inspectorBackgroundLight,
                searchBackground: Color.white
            )
        }
    }
}
