import SwiftUI
import OCIExplorerCore

struct DiagnosticsView: View {
    @ObservedObject var logger: AppLogger
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(L10n.string("diagnostics.title"))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Button(L10n.string("common.close")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(AppButtonStyle(kind: .secondary))
                Button(L10n.string("diagnostics.clear")) {
                    logger.clear()
                }
                .buttonStyle(AppButtonStyle(kind: .secondary))
            }

            List(logger.entries) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        StatusBadge(title: localizedLevel(entry.level), kind: kind(for: entry.level))
                        Text(entry.category)
                            .font(.headline)
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Text(entry.timestamp.formatted(date: .abbreviated, time: .standard))
                            .font(.caption)
                            .foregroundStyle(theme.textTertiary)
                    }
                    Text(entry.message)
                        .foregroundStyle(theme.textPrimary)
                    if !entry.metadata.isEmpty {
                        ForEach(entry.metadata.keys.sorted(), id: \.self) { key in
                            Text("\(key): \(entry.metadata[key] ?? "")")
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(24)
        .background(theme.appBackground)
    }

    private func kind(for level: LogLevel) -> StatusBadgeKind {
        switch level {
        case .debug:
            return .info
        case .info:
            return .info
        case .warning:
            return .warning
        case .error:
            return .error
        }
    }

    private func localizedLevel(_ level: LogLevel) -> String {
        switch level {
        case .debug:
            return L10n.string("diagnostics.level.debug")
        case .info:
            return L10n.string("diagnostics.level.info")
        case .warning:
            return L10n.string("diagnostics.level.warning")
        case .error:
            return L10n.string("diagnostics.level.error")
        }
    }
}
