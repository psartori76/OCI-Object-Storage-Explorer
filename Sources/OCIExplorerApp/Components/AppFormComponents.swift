import AppKit
import SwiftUI
import OCIExplorerCore

struct AppPanelCard<Content: View>: View {
    let title: String?
    let subtitle: String?
    @ViewBuilder let content: Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)
        let shadow = AppShadows.card(for: colorScheme)
        VStack(alignment: .leading, spacing: 18) {
            if let title {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }

            content
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
        .shadow(color: shadow.color, radius: shadow.radius, y: shadow.y)
    }
}

struct AppSectionCard<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }
            }
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
    }
}

struct AppFieldLabel: View {
    let title: String
    let helper: String?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
            if let helper {
                Text(helper)
                    .font(.caption)
                    .foregroundStyle(theme.textTertiary)
            }
        }
    }
}

struct AppTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let error: String?
    let helper: String?

    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    init(
        _ title: String,
        placeholder: String,
        text: Binding<String>,
        error: String? = nil,
        helper: String? = nil
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.error = error
        self.helper = helper
    }

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)
        VStack(alignment: .leading, spacing: 8) {
            AppFieldLabel(title: title, helper: helper)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(fieldBackground)
                .overlay(fieldBorder)
                .shadow(color: isFocused ? AppShadows.softGlowBlue : .clear, radius: 18)
                .focused($isFocused)
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(BrandColors.error)
            }
        }
    }

    private var fieldBackground: some View {
        let theme = AppTheme.current(for: colorScheme)
        return RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(theme.searchBackground)
    }

    private var fieldBorder: some View {
        let theme = AppTheme.current(for: colorScheme)
        return RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(borderColor(theme), lineWidth: isFocused ? 1.5 : 1)
    }

    private func borderColor(_ theme: AppThemePalette) -> Color {
        if error != nil {
            return BrandColors.error
        }
        return isFocused ? theme.focusRing : theme.borderSubtle
    }
}

struct AppSecureField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let error: String?
    let helper: String?

    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    init(
        _ title: String,
        placeholder: String,
        text: Binding<String>,
        error: String? = nil,
        helper: String? = nil
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.error = error
        self.helper = helper
    }

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)
        VStack(alignment: .leading, spacing: 8) {
            AppFieldLabel(title: title, helper: helper)
            SecureField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(theme.searchBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(error != nil ? BrandColors.error : (isFocused ? theme.focusRing : theme.borderSubtle), lineWidth: isFocused ? 1.5 : 1)
                )
                .shadow(color: isFocused ? AppShadows.softGlowBlue : .clear, radius: 18)
                .focused($isFocused)
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(BrandColors.error)
            }
        }
    }
}

struct AppPickerField<SelectionValue: Hashable, Content: View>: View {
    let title: String
    let helper: String?
    @Binding var selection: SelectionValue
    @ViewBuilder let content: Content

    init(
        _ title: String,
        helper: String? = nil,
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.helper = helper
        self._selection = selection
        self.content = content()
    }

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)
        VStack(alignment: .leading, spacing: 8) {
            AppFieldLabel(title: title, helper: helper)
            Picker(title, selection: $selection) {
                content
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.elevatedBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(theme.borderSubtle, lineWidth: 1)
            )
        }
    }
}

struct AppFileField: View {
    let title: String
    let path: String
    let statusText: String
    let error: String?
    let actionTitle: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)
        VStack(alignment: .leading, spacing: 8) {
            AppFieldLabel(title: title, helper: nil)
            HStack(spacing: 12) {
                Text(path.isEmpty ? L10n.string("auth.field.pem_file.none") : path)
                    .foregroundStyle(path.isEmpty ? theme.textTertiary : theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(theme.searchBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(error != nil ? BrandColors.error : theme.borderSubtle, lineWidth: 1)
                    )

                Button(actionTitle, action: action)
                    .buttonStyle(AppButtonStyle(kind: .secondary))
            }
            Text(statusText)
                .font(.caption)
                .foregroundStyle(error == nil ? theme.textTertiary : BrandColors.error)
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(BrandColors.error)
            }
        }
    }
}

enum AppButtonKind {
    case primary
    case secondary
    case destructive
}

struct AppButtonStyle: ButtonStyle {
    let kind: AppButtonKind
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        let theme = AppTheme.current(for: colorScheme)
        let isPressed = configuration.isPressed

        return configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(foregroundColor(theme, isPressed: isPressed))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(backgroundColor(theme, isPressed: isPressed), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(borderColor(theme), lineWidth: borderLineWidth)
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func backgroundColor(_ theme: AppThemePalette, isPressed: Bool) -> Color {
        switch kind {
        case .primary:
            return isPressed ? BrandColors.brandBlueDeep : BrandColors.brandBluePrimary
        case .secondary:
            return theme.elevatedBackground
        case .destructive:
            return colorScheme == .dark ? BrandColors.destructiveBackgroundDark : BrandColors.destructiveBackgroundLight
        }
    }

    private func foregroundColor(_ theme: AppThemePalette, isPressed: Bool) -> Color {
        switch kind {
        case .primary:
            return .white
        case .secondary:
            return theme.textPrimary
        case .destructive:
            return BrandColors.error
        }
    }

    private func borderColor(_ theme: AppThemePalette) -> Color {
        switch kind {
        case .primary:
            return .clear
        case .secondary, .destructive:
            return theme.borderSubtle
        }
    }

    private var borderLineWidth: CGFloat {
        switch kind {
        case .primary:
            return 0
        case .secondary, .destructive:
            return 1
        }
    }
}
