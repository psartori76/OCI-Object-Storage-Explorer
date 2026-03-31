import AppKit
import SwiftUI
import OCIExplorerCore

struct AuthenticationView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    let onConnect: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)

        ZStack {
            authenticationBackground(theme: theme)

            VStack(spacing: 28) {
                header(theme: theme)

                AppPanelCard {
                    VStack(alignment: .leading, spacing: 20) {
                        if viewModel.hasProfiles {
                            savedProfilesContent(theme: theme)
                        } else {
                            emptyProfilesContent(theme: theme)
                        }

                        actionRow
                        statusArea
                    }
                }
                .frame(maxWidth: 760)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 40)
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.isPresentingProfileEditor },
                set: { isPresented in
                    if !isPresented {
                        viewModel.dismissProfileEditor()
                    }
                }
            )
        ) {
            AuthenticationProfileEditorSheet(
                viewModel: viewModel,
                onConnect: onConnect
            )
            .frame(minWidth: 760, minHeight: 760)
        }
        .animation(.easeInOut(duration: 0.22), value: viewModel.mode)
    }

    private func authenticationBackground(theme: AppThemePalette) -> some View {
        ZStack {
            theme.appBackground
                .ignoresSafeArea()

            Circle()
                .fill(BrandColors.brandBluePrimary.opacity(0.10))
                .frame(width: 380, height: 380)
                .blur(radius: 40)
                .offset(x: -320, y: -180)

            Circle()
                .fill(BrandColors.brandBlueLight.opacity(0.10))
                .frame(width: 300, height: 300)
                .blur(radius: 40)
                .offset(x: 360, y: 210)
        }
    }

    private func header(theme: AppThemePalette) -> some View {
        VStack(spacing: 12) {
            Text("OCI Object Storage Explorer")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textPrimary)

            Text("Acesse seus buckets e objetos no OCI com uma experiência nativa para macOS.")
                .font(.title3)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 640)
        }
    }

    private func savedProfilesContent(theme: AppThemePalette) -> some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Perfis salvos")
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.profiles) { profile in
                            Button {
                                viewModel.chooseProfile(id: profile.id)
                            } label: {
                                AuthenticationProfileRow(
                                    profile: profile,
                                    isSelected: viewModel.draft.selectedProfileID == profile.id
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 240)
            }
            .frame(maxWidth: 320, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                Text("Perfil selecionado")
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)

                if let profile = viewModel.selectedProfile {
                    Text(profile.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.selectedProfileSummary, id: \.0) { item in
                            HStack {
                                Text(item.0)
                                    .foregroundStyle(theme.textSecondary)
                                Spacer()
                                Text(item.1)
                                    .foregroundStyle(theme.textPrimary)
                                    .textSelection(.enabled)
                            }
                            .font(.subheadline)
                        }
                    }

                    Text("Os detalhes técnicos do OCI só aparecem quando você escolher editar ou criar um perfil.")
                        .font(.footnote)
                        .foregroundStyle(theme.textTertiary)
                        .padding(.top, 4)
                } else {
                    Text("Escolha um perfil salvo para conectar-se rapidamente.")
                        .font(.body)
                        .foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func emptyProfilesContent(theme: AppThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Perfis salvos")
                .font(.headline)
                .foregroundStyle(theme.textPrimary)
            Text("Nenhum perfil configurado ainda. Crie um novo perfil para começar a se conectar ao OCI Object Storage.")
                .font(.body)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                onConnect()
            } label: {
                if viewModel.isConnecting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Conectar")
                        .frame(minWidth: 110)
                }
            }
            .buttonStyle(AppButtonStyle(kind: .primary))
            .disabled(viewModel.selectedProfile == nil || viewModel.isConnecting || viewModel.isTestingConnection)

            Button("Novo perfil") {
                viewModel.startCreatingProfile()
            }
            .buttonStyle(AppButtonStyle(kind: .secondary))

            Button("Editar perfil") {
                viewModel.startEditingSelectedProfile()
            }
            .buttonStyle(AppButtonStyle(kind: .secondary))
            .disabled(viewModel.selectedProfile == nil)

            Button("Remover perfil", role: .destructive) {
                viewModel.deleteSelectedProfile()
            }
            .buttonStyle(AppButtonStyle(kind: .destructive))
            .disabled(viewModel.selectedProfile == nil)

            Spacer()
        }
    }

    @ViewBuilder
    private var statusArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let connectionStatus = viewModel.connectionStatus {
                StatusBadge(title: connectionStatus, kind: .success)
            }
            if let errorMessage = viewModel.errorMessage {
                StatusBadge(title: errorMessage, kind: .error)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AuthenticationProfileRow: View {
    let profile: AuthProfile
    let isSelected: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)

        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? BrandColors.brandBluePrimary : theme.textTertiary)
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                Text("\(profile.region) • \(profile.method.displayName)")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? theme.selectionFill : theme.elevatedBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? theme.selectionBorder : theme.borderSubtle, lineWidth: 1)
        )
    }
}

private struct AuthenticationProfileEditorSheet: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    let onConnect: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = AppTheme.current(for: colorScheme)

        ZStack {
            theme.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(viewModel.editorTitle)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(theme.textPrimary)
                            Text("Preencha os dados do perfil OCI com calma. Os detalhes técnicos ficam concentrados aqui para manter a entrada do app mais simples.")
                                .font(.body)
                                .foregroundStyle(theme.textSecondary)
                                .frame(maxWidth: 520, alignment: .leading)
                        }

                        Spacer()

                        Button("Fechar") {
                            viewModel.dismissProfileEditor()
                            dismiss()
                        }
                        .buttonStyle(AppButtonStyle(kind: .secondary))
                    }

                    if let errorMessage = viewModel.errorMessage {
                        StatusBadge(title: errorMessage, kind: .error)
                    } else if let connectionStatus = viewModel.connectionStatus {
                        StatusBadge(title: connectionStatus, kind: .success)
                    }

                    AppSectionCard(title: "Perfil", subtitle: "Identificação do perfil e método de autenticação.") {
                        VStack(spacing: 16) {
                            AppTextField(
                                "Nome do perfil",
                                placeholder: "Ex.: Produção OCI",
                                text: $viewModel.draft.profileName,
                                error: viewModel.validationErrors[.profileName]
                            )

                            VStack(alignment: .leading, spacing: 8) {
                                AppFieldLabel(title: "Método de autenticação", helper: "A arquitetura já está pronta para suportar outros métodos nas próximas iterações.")
                                Picker("Método", selection: $viewModel.draft.method) {
                                    Text(AuthenticationMethod.apiKey.displayName).tag(AuthenticationMethod.apiKey)
                                }
                                .pickerStyle(.segmented)
                                .disabled(true)
                            }
                        }
                    }

                    AppSectionCard(title: "Credenciais OCI", subtitle: "Somente os campos necessários para a conexão via API Key.") {
                        VStack(spacing: 16) {
                            AppTextField(
                                "Tenancy OCID",
                                placeholder: "ocid1.tenancy.oc1...",
                                text: $viewModel.draft.tenancyOCID,
                                error: viewModel.validationErrors[.tenancyOCID]
                            )
                            AppTextField(
                                "User OCID",
                                placeholder: "ocid1.user.oc1...",
                                text: $viewModel.draft.userOCID,
                                error: viewModel.validationErrors[.userOCID]
                            )
                            AppTextField(
                                "Fingerprint",
                                placeholder: "11:22:33:44:...",
                                text: $viewModel.draft.fingerprint,
                                error: viewModel.validationErrors[.fingerprint]
                            )

                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .center, spacing: 10) {
                                    AppFieldLabel(
                                        title: "Região",
                                        helper: viewModel.hasLoadedRegions
                                            ? "Escolha uma região subscribed do tenancy. O valor salvo continua sendo o region code."
                                            : "O app tenta carregar automaticamente as regiões subscribed do tenancy."
                                    )
                                    Spacer()
                                    if viewModel.isLoadingRegions {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                    Button("Atualizar regiões") {
                                        Task { await viewModel.loadSubscribedRegionsIfPossible() }
                                    }
                                    .buttonStyle(.borderless)
                                    .foregroundStyle(BrandColors.brandBluePrimary)
                                }

                                if viewModel.hasLoadedRegions && !viewModel.draft.isManualRegionEntry {
                                    Picker("Região", selection: $viewModel.draft.region) {
                                        ForEach(viewModel.regions) { region in
                                            Text(region.displayName).tag(region.regionCode)
                                        }
                                    }
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

                                    Button("Ou inserir manualmente") {
                                        viewModel.enableManualRegionEntry()
                                    }
                                    .buttonStyle(.link)
                                    .foregroundStyle(BrandColors.brandBluePrimary)
                                } else {
                                    AppTextField(
                                        "Região manual",
                                        placeholder: "sa-saopaulo-1",
                                        text: $viewModel.draft.region,
                                        error: viewModel.validationErrors[.region],
                                        helper: "Use este fallback se a lista automática não estiver disponível."
                                    )

                                    HStack(spacing: 12) {
                                        if viewModel.hasLoadedRegions {
                                            Button("Usar lista automática") {
                                                viewModel.useAutomaticRegionList()
                                            }
                                            .buttonStyle(.link)
                                            .foregroundStyle(BrandColors.brandBluePrimary)
                                        }

                                        AppPickerField("Regiões comuns", helper: "Fallback rápido para regiões conhecidas.", selection: $viewModel.draft.region) {
                                            ForEach(viewModel.commonRegions, id: \.self) { region in
                                                Text(region).tag(region)
                                            }
                                        }
                                        .frame(width: 260)
                                    }
                                }

                                if let regionError = viewModel.regionError {
                                    Text(regionError)
                                        .font(.caption)
                                        .foregroundStyle(theme.textTertiary)
                                }
                            }

                            AppTextField(
                                "Namespace",
                                placeholder: "Deixe em branco para detectar automaticamente",
                                text: $viewModel.draft.namespace,
                                helper: "Opcional"
                            )
                            AppTextField(
                                "Compartment OCID padrão",
                                placeholder: "ocid1.compartment.oc1...",
                                text: $viewModel.draft.defaultCompartmentOCID,
                                helper: "Opcional. Se ficar vazio, o app usa o tenancy OCID."
                            )
                        }
                    }

                    AppSectionCard(title: "Chave privada", subtitle: "Selecione o arquivo PEM privado correspondente à API Key cadastrada no OCI.") {
                        VStack(spacing: 16) {
                            AppFileField(
                                title: "Arquivo PEM",
                                path: viewModel.draft.privateKeyPath,
                                statusText: viewModel.draft.privateKeyPEM.isEmpty ? "Nenhuma chave carregada ainda." : "Chave privada carregada com sucesso na sessão atual.",
                                error: viewModel.validationErrors[.privateKey],
                                actionTitle: "Selecionar arquivo..."
                            ) {
                                viewModel.importPrivateKey()
                            }

                            AppSecureField(
                                "Passphrase",
                                placeholder: "Informe somente se a chave exigir",
                                text: $viewModel.draft.passphrase,
                                helper: "Opcional"
                            )

                            Toggle("Salvar credenciais com segurança no Keychain do macOS", isOn: $viewModel.draft.rememberMe)
                                .toggleStyle(.switch)
                                .foregroundStyle(theme.textPrimary)
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            Task { await viewModel.testConnection() }
                        } label: {
                            if viewModel.isTestingConnection {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Testar conexão")
                            }
                        }
                        .buttonStyle(AppButtonStyle(kind: .secondary))

                        Button("Salvar perfil") {
                            viewModel.saveProfile()
                            if !viewModel.isPresentingProfileEditor {
                                dismiss()
                            }
                        }
                        .buttonStyle(AppButtonStyle(kind: .secondary))

                        Button("Cancelar") {
                            viewModel.dismissProfileEditor()
                            dismiss()
                        }
                        .buttonStyle(AppButtonStyle(kind: .secondary))

                        Spacer()

                        Button {
                            onConnect()
                        } label: {
                            if viewModel.isConnecting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Conectar")
                                    .frame(minWidth: 110)
                            }
                        }
                        .buttonStyle(AppButtonStyle(kind: .primary))
                    }
                    .padding(.top, 4)
                }
                .padding(28)
                .frame(maxWidth: 860)
                .frame(maxWidth: .infinity)
            }
        }
    }
}
