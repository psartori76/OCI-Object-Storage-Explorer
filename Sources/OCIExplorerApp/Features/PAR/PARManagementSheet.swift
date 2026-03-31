import SwiftUI
import OCIExplorerCore

struct PARManagementSheet: View {
    @ObservedObject var viewModel: PARManagementViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)

        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.title)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                    Text(viewModel.subtitle)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                Button("Fechar") {
                    dismiss()
                }
                .buttonStyle(AppButtonStyle(kind: .secondary))
            }

            HStack {
                Button("Criar novo link") {
                    viewModel.openCreateModal()
                }
                .buttonStyle(AppButtonStyle(kind: .primary))

                Button("Atualizar") {
                    Task { await viewModel.refresh() }
                }
                .buttonStyle(AppButtonStyle(kind: .secondary))

                if viewModel.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()
            }

            PARListView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(24)
        .background(theme.appBackground)
        .overlay(alignment: .bottom) {
            if let toast = viewModel.toast {
                HStack(spacing: 12) {
                    Text(toast.message)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                    if let actionTitle = toast.actionTitle, let par = toast.par {
                        Button(actionTitle) {
                            viewModel.copyURL(for: par)
                            viewModel.consumeToast()
                        }
                        .buttonStyle(AppButtonStyle(kind: .primary))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(theme.cardBackground, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(theme.borderSubtle, lineWidth: 1)
                )
                .padding(.bottom, 12)
            }
        }
        .sheet(isPresented: $viewModel.isCreateModalPresented) {
            CreatePARModalView(viewModel: viewModel)
                .frame(minWidth: 540, minHeight: 520)
        }
        .task {
            await viewModel.refresh()
        }
    }
}

struct PARListView: View {
    @ObservedObject var viewModel: PARManagementViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        switch viewModel.state {
        case .idle, .loading:
            PARLoadingView(title: "Carregando links compartilháveis…")
        case .empty:
            EmptyStateView(
                systemImage: "link",
                title: viewModel.emptyTitle,
                message: viewModel.emptyMessage
            )
        case let .error(message):
            EmptyStateView(
                systemImage: "exclamationmark.triangle",
                title: "Não foi possível carregar os links",
                message: message
            )
        case .loaded:
            loadedTable
        }
    }

    private var loadedTable: some View {
        let theme = AppTheme.current(for: colorScheme)

        return Table(viewModel.pars) {
            TableColumn("Nome") { par in
                VStack(alignment: .leading, spacing: 4) {
                    Text(par.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    Text(par.truncatedURL)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
            }
            .width(min: 260, ideal: 320)

            TableColumn("Tipo") { par in
                Text(par.scopeTitle)
                    .foregroundStyle(theme.textSecondary)
            }
            .width(min: 80, ideal: 100)

            TableColumn("Acesso") { par in
                Text(par.accessTitle)
                    .foregroundStyle(theme.textSecondary)
            }
            .width(min: 120, ideal: 150)

            TableColumn("Expiração") { par in
                Text(par.timeExpires.friendlyDateText)
                    .foregroundStyle(theme.textSecondary)
            }
            .width(min: 160, ideal: 190)

            TableColumn("Status") { par in
                StatusBadge(title: par.statusTitle, kind: par.isExpired ? .warning : .success)
            }
            .width(min: 90, ideal: 110)

            TableColumn("Ações") { par in
                HStack(spacing: 8) {
                    Button("Copiar") {
                        viewModel.copyURL(for: par)
                    }
                    .buttonStyle(.borderless)

                    Button("Excluir", role: .destructive) {
                        Task { await viewModel.deletePAR(par) }
                    }
                    .buttonStyle(.borderless)
                }
            }
            .width(min: 140, ideal: 160)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
    }
}

private struct PARLoadingView: View {
    let title: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)

        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text(title)
                .font(.body)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CreatePARModalView: View {
    @ObservedObject var viewModel: PARManagementViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)

        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Criar novo link")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                    Text("Configure o escopo, o tipo de acesso e a expiração do novo Pre-Authenticated Request.")
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
            }

            if let inlineErrorMessage = viewModel.inlineErrorMessage {
                StatusBadge(title: inlineErrorMessage, kind: .error)
            }

            AppSectionCard(title: "Escopo") {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Escopo", selection: $viewModel.draft.scope) {
                        ForEach(PARDisplayScope.allCases) { scope in
                            Text(scope.title).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)

                    if viewModel.draft.scope == .object {
                        AppTextField(
                            "Objeto",
                            placeholder: "nome/do/objeto.ext",
                            text: $viewModel.draft.objectName
                        )
                    }
                }
            }

            AppSectionCard(title: "Configuração") {
                VStack(spacing: 16) {
                    AppTextField(
                        "Nome",
                        placeholder: "Ex.: Download temporário",
                        text: $viewModel.draft.name
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        AppFieldLabel(title: "Tipo de acesso", helper: nil)
                        Picker("Tipo de acesso", selection: $viewModel.draft.accessType) {
                            accessTypeOptions
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        AppFieldLabel(title: "Expiração", helper: viewModel.expirationDescription)
                        DatePicker("Expiração", selection: $viewModel.draft.expiresAt)
                            .labelsHidden()
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancelar") {
                    viewModel.dismissCreateModal()
                    dismiss()
                }
                .buttonStyle(AppButtonStyle(kind: .secondary))

                Button {
                    Task {
                        await viewModel.createPAR()
                        if !viewModel.isCreateModalPresented {
                            dismiss()
                        }
                    }
                } label: {
                    if viewModel.isCreating {
                        ProgressView()
                    } else {
                        Text("Criar link")
                            .frame(minWidth: 110)
                    }
                }
                .buttonStyle(AppButtonStyle(kind: .primary))
            }
        }
        .padding(24)
        .background(theme.appBackground)
    }

    @ViewBuilder
    private var accessTypeOptions: some View {
        if viewModel.draft.scope == .bucket {
            Text("Leitura").tag(PARAccessType.anyObjectRead)
            Text("Escrita").tag(PARAccessType.anyObjectWrite)
            Text("Leitura/Escrita").tag(PARAccessType.anyObjectReadWrite)
        } else {
            Text("Leitura").tag(PARAccessType.objectRead)
            Text("Escrita").tag(PARAccessType.objectWrite)
            Text("Leitura/Escrita").tag(PARAccessType.objectReadWrite)
        }
    }
}
