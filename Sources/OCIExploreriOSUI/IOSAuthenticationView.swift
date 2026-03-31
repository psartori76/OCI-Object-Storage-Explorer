import SwiftUI
import OCIExplorerCore
import OCIExplorerShared

struct IOSAuthenticationView: View {
    @ObservedObject var viewModel: IOSAuthenticationViewModel
    let onConnected: @MainActor (ExplorerSession) async -> Void

    var body: some View {
        NavigationStack {
            Form {
                if !viewModel.profiles.isEmpty {
                    Section("Perfis salvos") {
                        ForEach(viewModel.profiles) { profile in
                            Button {
                                viewModel.selectProfile(id: profile.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(profile.name)
                                            .foregroundStyle(.primary)
                                        Text("\(profile.region) • \(profile.method.displayName)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if viewModel.selectedProfileID == profile.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Perfil") {
                    TextField("Nome do perfil", text: $viewModel.profileName)
                    Picker("Região", selection: $viewModel.regionCode) {
                        ForEach(viewModel.availableRegions) { region in
                            Text(region.displayName).tag(region.regionCode)
                        }
                    }
                }

                Section("Credenciais OCI") {
                    TextField("Tenancy OCID", text: $viewModel.tenancyOCID)
                        .disableMobileTextHelpers()
                    TextField("User OCID", text: $viewModel.userOCID)
                        .disableMobileTextHelpers()
                    TextField("Fingerprint", text: $viewModel.fingerprint)
                        .disableMobileTextHelpers()
                    TextField("Namespace (opcional)", text: $viewModel.namespace)
                        .disableMobileTextHelpers()
                    TextField("Compartment OCID padrão (opcional)", text: $viewModel.compartmentOCID)
                        .disableMobileTextHelpers()
                }

                Section("Chave privada PEM") {
                    TextEditor(text: $viewModel.privateKeyPEM)
                        .frame(minHeight: 180)
                        .font(.system(.footnote, design: .monospaced))
                    SecureField("Passphrase (opcional)", text: $viewModel.passphrase)
                    Toggle("Salvar perfil e segredos no dispositivo", isOn: $viewModel.rememberMe)
                }

                if let statusMessage = viewModel.statusMessage {
                    Section {
                        Label(statusMessage, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task {
                            do {
                                let session = try await viewModel.connect()
                                await onConnected(session)
                            } catch {
                                viewModel.errorMessage = AppError.from(error).localizedDescription
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isConnecting {
                                ProgressView()
                            } else {
                                Text("Conectar")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(viewModel.isConnecting)
                }
            }
            .navigationTitle("OCI Explorer")
        }
    }
}

private extension View {
    @ViewBuilder
    func disableMobileTextHelpers() -> some View {
        #if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        self
        #endif
    }
}
