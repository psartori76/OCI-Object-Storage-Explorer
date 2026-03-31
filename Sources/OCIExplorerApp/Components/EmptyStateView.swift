import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)
        VStack {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(theme.elevatedBackground)
                        .frame(width: 72, height: 72)
                    Image(systemName: systemImage)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                }

                VStack(spacing: 8) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                    Text(message)
                        .font(.body)
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 440)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 34)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(theme.borderSubtle, lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}
