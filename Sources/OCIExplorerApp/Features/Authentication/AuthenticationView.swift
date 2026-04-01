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
            Text(L10n.string("auth.title"))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textPrimary)

            Text(L10n.string("auth.subtitle"))
                .font(.title3)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 640)
        }
    }

    private func savedProfilesContent(theme: AppThemePalette) -> some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.string("auth.saved_profiles"))
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
                Text(L10n.string("auth.selected_profile"))
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

                    Text(L10n.string("auth.selected_profile.helper"))
                        .font(.footnote)
                        .foregroundStyle(theme.textTertiary)
                        .padding(.top, 4)
                } else {
                    Text(L10n.string("auth.selected_profile.empty"))
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
            Text(L10n.string("auth.saved_profiles"))
                .font(.headline)
                .foregroundStyle(theme.textPrimary)
            Text(L10n.string("auth.empty_profiles"))
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
                    Text(L10n.string("auth.connect"))
                        .frame(minWidth: 110)
                }
            }
            .buttonStyle(AppButtonStyle(kind: .primary))
            .disabled(viewModel.selectedProfile == nil || viewModel.isConnecting || viewModel.isTestingConnection)

            Button(L10n.string("auth.new_profile")) {
                viewModel.startCreatingProfile()
            }
            .buttonStyle(AppButtonStyle(kind: .secondary))

            Button(L10n.string("auth.edit_profile")) {
                viewModel.startEditingSelectedProfile()
            }
            .buttonStyle(AppButtonStyle(kind: .secondary))
            .disabled(viewModel.selectedProfile == nil)

            Button(L10n.string("auth.remove_profile"), role: .destructive) {
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
                            Text(L10n.string("auth.editor.description"))
                                .font(.body)
                                .foregroundStyle(theme.textSecondary)
                                .frame(maxWidth: 520, alignment: .leading)
                        }

                        Spacer()

                        Button(L10n.string("common.close")) {
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

                    AppSectionCard(title: L10n.string("auth.section.profile.title"), subtitle: L10n.string("auth.section.profile.subtitle")) {
                        VStack(spacing: 16) {
                            AppTextField(
                                L10n.string("auth.field.profile_name"),
                                placeholder: L10n.string("auth.field.profile_name.placeholder"),
                                text: $viewModel.draft.profileName,
                                error: viewModel.validationErrors[.profileName]
                            )

                            VStack(alignment: .leading, spacing: 8) {
                                AppFieldLabel(title: L10n.string("auth.field.auth_method"), helper: L10n.string("auth.field.auth_method.helper"))
                                Picker(L10n.string("auth.field.auth_method"), selection: $viewModel.draft.method) {
                                    Text(AuthenticationMethod.apiKey.displayName).tag(AuthenticationMethod.apiKey)
                                }
                                .pickerStyle(.segmented)
                                .disabled(true)
                            }
                        }
                    }

                    AppSectionCard(title: L10n.string("auth.section.credentials.title"), subtitle: L10n.string("auth.section.credentials.subtitle")) {
                        VStack(spacing: 16) {
                            AppTextField(
                                L10n.string("auth.field.tenancy_ocid"),
                                placeholder: "ocid1.tenancy.oc1...",
                                text: $viewModel.draft.tenancyOCID,
                                error: viewModel.validationErrors[.tenancyOCID]
                            )
                            AppTextField(
                                L10n.string("auth.field.user_ocid"),
                                placeholder: "ocid1.user.oc1...",
                                text: $viewModel.draft.userOCID,
                                error: viewModel.validationErrors[.userOCID]
                            )
                            AppTextField(
                                L10n.string("auth.field.fingerprint"),
                                placeholder: "11:22:33:44:...",
                                text: $viewModel.draft.fingerprint,
                                error: viewModel.validationErrors[.fingerprint]
                            )

                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .center, spacing: 10) {
                                    AppFieldLabel(
                                        title: L10n.string("auth.field.region"),
                                        helper: viewModel.hasLoadedRegions
                                            ? L10n.string("auth.field.region.helper.loaded")
                                            : L10n.string("auth.field.region.helper.loading")
                                    )
                                    Spacer()
                                    if viewModel.isLoadingRegions {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                    Button(L10n.string("auth.field.region.refresh")) {
                                        Task { await viewModel.loadSubscribedRegionsIfPossible() }
                                    }
                                    .buttonStyle(.borderless)
                                    .foregroundStyle(BrandColors.brandBluePrimary)
                                }

                                if viewModel.hasLoadedRegions && !viewModel.draft.isManualRegionEntry {
                                    Picker(L10n.string("auth.field.region"), selection: $viewModel.draft.region) {
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

                                    Button(L10n.string("auth.field.region.manual.action")) {
                                        viewModel.enableManualRegionEntry()
                                    }
                                    .buttonStyle(.link)
                                    .foregroundStyle(BrandColors.brandBluePrimary)
                                } else {
                                    AppTextField(
                                        L10n.string("auth.field.region.manual"),
                                        placeholder: L10n.string("auth.field.region.manual.placeholder"),
                                        text: $viewModel.draft.region,
                                        error: viewModel.validationErrors[.region],
                                        helper: L10n.string("auth.field.region.manual.helper")
                                    )

                                    HStack(spacing: 12) {
                                        if viewModel.hasLoadedRegions {
                                            Button(L10n.string("auth.field.region.automatic.action")) {
                                                viewModel.useAutomaticRegionList()
                                            }
                                            .buttonStyle(.link)
                                            .foregroundStyle(BrandColors.brandBluePrimary)
                                        }

                                        AppPickerField(L10n.string("auth.field.region.common"), helper: L10n.string("auth.field.region.common.helper"), selection: $viewModel.draft.region) {
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
                                L10n.string("auth.field.namespace"),
                                placeholder: L10n.string("auth.field.namespace.placeholder"),
                                text: $viewModel.draft.namespace,
                                helper: L10n.string("auth.field.optional")
                            )
                            AppTextField(
                                L10n.string("auth.field.default_compartment"),
                                placeholder: "ocid1.compartment.oc1...",
                                text: $viewModel.draft.defaultCompartmentOCID,
                                helper: L10n.string("auth.field.default_compartment.helper")
                            )
                        }
                    }

                    AppSectionCard(title: L10n.string("auth.section.private_key.title"), subtitle: L10n.string("auth.section.private_key.subtitle")) {
                        VStack(spacing: 16) {
                            AppFileField(
                                title: L10n.string("auth.field.pem_file"),
                                path: viewModel.draft.privateKeyPath,
                                statusText: viewModel.draft.privateKeyPEM.isEmpty ? L10n.string("auth.field.pem_file.status.empty") : L10n.string("auth.field.pem_file.status.loaded"),
                                error: viewModel.validationErrors[.privateKey],
                                actionTitle: L10n.string("auth.field.pem_file.action")
                            ) {
                                viewModel.importPrivateKey()
                            }

                            AppSecureField(
                                L10n.string("auth.field.passphrase"),
                                placeholder: L10n.string("auth.field.passphrase.placeholder"),
                                text: $viewModel.draft.passphrase,
                                helper: L10n.string("auth.field.optional")
                            )

                            Toggle(L10n.string("auth.field.remember_me"), isOn: $viewModel.draft.rememberMe)
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
                                Text(L10n.string("auth.test_connection"))
                            }
                        }
                        .buttonStyle(AppButtonStyle(kind: .secondary))

                        Button(L10n.string("auth.save_profile")) {
                            viewModel.saveProfile()
                            if !viewModel.isPresentingProfileEditor {
                                dismiss()
                            }
                        }
                        .buttonStyle(AppButtonStyle(kind: .secondary))

                        Button(L10n.string("common.cancel")) {
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
                                Text(L10n.string("auth.connect"))
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
