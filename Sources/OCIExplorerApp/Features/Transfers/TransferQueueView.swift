import SwiftUI
import OCIExplorerCore
import OCIExplorerServices

struct TransferQueueView: View {
    @ObservedObject var coordinator: TransferCoordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Fila de transferências")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                if coordinator.hasActiveTransfers {
                    StatusBadge(title: "Processando", kind: .info)
                }
                Button("Fechar") {
                    dismiss()
                }
                .buttonStyle(AppButtonStyle(kind: .secondary))
                .keyboardShortcut(.cancelAction)
                Button("Limpar concluídas") {
                    coordinator.clearCompleted()
                }
                .buttonStyle(AppButtonStyle(kind: .secondary))
            }

            transferSummaryCard

            List(coordinator.records) { record in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(record.displayName, systemImage: record.direction == .upload ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        StatusBadge(
                            title: title(for: record.status),
                            kind: kind(for: record.status)
                        )
                    }
                    ProgressView(value: record.progress)
                    Text(progressLabel(for: record))
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)
                    Text("\(record.sourcePath) → \(record.destinationPath)")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                    if let errorMessage = record.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(BrandColors.error)
                    }
                    HStack {
                        if record.status == .running {
                            Button("Cancelar") {
                                coordinator.cancel(recordID: record.id)
                            }
                            .buttonStyle(AppButtonStyle(kind: .destructive))
                        }
                        if record.status == .failed || record.status == .cancelled {
                            Button("Retry") {
                                coordinator.retry(recordID: record.id)
                            }
                            .buttonStyle(AppButtonStyle(kind: .secondary))
                        }
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .padding(24)
        .background(theme.appBackground)
    }

    private var transferSummaryCard: some View {
        let theme = AppTheme.current(for: colorScheme)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                summaryPill(title: "Na fila", value: coordinator.queuedCount.description)
                summaryPill(title: "Em andamento", value: coordinator.runningCount.description)
                summaryPill(title: "Concluídos", value: coordinator.completedCount.description)
                summaryPill(title: "Falharam", value: coordinator.failedCount.description)
            }

            ProgressView(value: coordinator.overallProgress)
                .progressViewStyle(.linear)

            Text(coordinator.hasActiveTransfers
                 ? "Progresso global: \(Int((coordinator.overallProgress * 100).rounded()))%"
                 : "Nenhuma transferência ativa no momento.")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(16)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
    }

    private func summaryPill(title: String, value: String) -> some View {
        let theme = AppTheme.current(for: colorScheme)
        return VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(theme.textTertiary)
            Text(value)
                .font(.headline)
                .foregroundStyle(theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func kind(for status: TransferStatus) -> StatusBadgeKind {
        switch status {
        case .queued:
            return .warning
        case .running:
            return .info
        case .completed:
            return .success
        case .failed:
            return .error
        case .cancelled:
            return .warning
        }
    }

    private func title(for status: TransferStatus) -> String {
        switch status {
        case .queued:
            return "Pendente"
        case .running:
            return "Enviando"
        case .completed:
            return "Concluído"
        case .failed:
            return "Falhou"
        case .cancelled:
            return "Cancelado"
        }
    }

    private func progressLabel(for record: TransferRecord) -> String {
        switch record.status {
        case .queued:
            return "Aguardando na fila"
        case .running:
            let percentage = Int((record.progress * 100).rounded())
            return percentage > 0 ? "\(percentage)% concluído" : "Preparando transferência…"
        case .completed:
            return "Transferência concluída"
        case .failed:
            return "Falha na transferência"
        case .cancelled:
            return "Transferência cancelada"
        }
    }
}
