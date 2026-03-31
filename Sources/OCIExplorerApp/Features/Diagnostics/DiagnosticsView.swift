import SwiftUI
import OCIExplorerCore

struct DiagnosticsView: View {
    @ObservedObject var logger: AppLogger
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Diagnóstico")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Button("Limpar") {
                    logger.clear()
                }
                .buttonStyle(AppButtonStyle(kind: .secondary))
            }

            List(logger.entries) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        StatusBadge(title: entry.level.rawValue.uppercased(), kind: kind(for: entry.level))
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
}
