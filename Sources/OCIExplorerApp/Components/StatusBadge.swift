import SwiftUI

enum StatusBadgeKind {
    case success
    case warning
    case error
    case info
}

struct StatusBadge: View {
    let title: String
    let kind: StatusBadgeKind

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(accentColor)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(backgroundColor, in: Capsule())
        .overlay(
            Capsule()
                .stroke(accentColor.opacity(0.16), lineWidth: 1)
        )
        .foregroundStyle(textColor)
    }

    private var backgroundColor: Color {
        switch kind {
        case .success:
            return colorScheme == .dark ? BrandColors.successToastDark : BrandColors.successToastLight
        case .warning:
            return colorScheme == .dark ? BrandColors.warningToastDark : BrandColors.warningToastLight
        case .error:
            return colorScheme == .dark ? BrandColors.errorToastDark : BrandColors.errorToastLight
        case .info:
            return colorScheme == .dark ? BrandColors.infoToastDark : BrandColors.infoToastLight
        }
    }

    private var textColor: Color {
        switch kind {
        case .success:
            return BrandColors.successToastText
        case .warning:
            return BrandColors.warningToastText
        case .error:
            return BrandColors.errorToastText
        case .info:
            return colorScheme == .dark ? BrandColors.brandBlueLight : BrandColors.brandBluePrimary
        }
    }

    private var accentColor: Color {
        switch kind {
        case .success:
            return BrandColors.success
        case .warning:
            return BrandColors.warning
        case .error:
            return BrandColors.error
        case .info:
            return BrandColors.info
        }
    }
}
