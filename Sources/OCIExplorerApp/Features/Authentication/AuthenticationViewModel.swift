import Combine
import Foundation
import OCIExplorerCore
import OCIExplorerShared
import OCIExplorerServices

enum AuthenticationMode: Equatable {
    case selectingProfile
    case creatingProfile
    case editingProfile
}

enum AuthenticationField: Hashable {
    case profileName
    case tenancyOCID
    case userOCID
    case fingerprint
    case region
    case privateKey
}

struct AuthenticationDraft: Equatable {
    var selectedProfileID: UUID?
    var profileName = L10n.string("auth.field.profile_name.default")
    var method: AuthenticationMethod = .apiKey
    var tenancyOCID = ""
    var userOCID = ""
    var fingerprint = ""
    var region = "sa-saopaulo-1"
    var namespace = ""
    var defaultCompartmentOCID = ""
    var privateKeyPath = ""
    var privateKeyPEM = ""
    var passphrase = ""
    var rememberMe = true
    var isManualRegionEntry = false

    mutating func clearSecrets() {
        privateKeyPath = ""
        privateKeyPEM = ""
        passphrase = ""
    }
}

@MainActor
final class AuthenticationViewModel: ObservableObject {
    @Published var profiles: [AuthProfile] = []
    @Published var draft = AuthenticationDraft()
    @Published var mode: AuthenticationMode = .selectingProfile
    @Published var isTestingConnection = false
    @Published var isConnecting = false
    @Published var isLoadingRegions = false
    @Published var connectionStatus: String?
    @Published var errorMessage: String?
    @Published var regionError: String?
    @Published var validationErrors: [AuthenticationField: String] = [:]
    @Published var regions: [OCIRegion] = []

    private let profileStore: ProfileStoreProtocol
    private let keychainService: KeychainServiceProtocol
    private let objectStorageService: OCIObjectStorageServiceProtocol
    private let identityService: OCIIdentityServiceProtocol
    private let logger: AppLogger

    init(
        profileStore: ProfileStoreProtocol,
        keychainService: KeychainServiceProtocol,
        objectStorageService: OCIObjectStorageServiceProtocol,
        identityService: OCIIdentityServiceProtocol,
        logger: AppLogger
    ) {
        self.profileStore = profileStore
        self.keychainService = keychainService
        self.objectStorageService = objectStorageService
        self.identityService = identityService
        self.logger = logger
        loadProfiles()
        if let firstProfile = profiles.first {
            selectProfile(firstProfile)
        }
    }

    func loadProfiles() {
        do {
            profiles = try profileStore.loadProfiles()
        } catch {
            errorMessage = AppError.from(error).localizedDescription
        }
    }

    func selectProfile(_ profile: AuthProfile?) {
        guard let profile else {
            draft = AuthenticationDraft()
            connectionStatus = nil
            errorMessage = nil
            validationErrors = [:]
            regionError = nil
            regions = []
            return
        }

        draft.selectedProfileID = profile.id
        draft.profileName = profile.name
        draft.method = profile.method
        draft.tenancyOCID = profile.tenancyOCID
        draft.userOCID = profile.userOCID
        draft.fingerprint = profile.fingerprint
        draft.region = profile.region
        draft.namespace = profile.namespace ?? ""
        draft.defaultCompartmentOCID = profile.defaultCompartmentOCID ?? ""
        draft.privateKeyPath = profile.privateKeyPathHint ?? ""
        draft.rememberMe = profile.rememberMe
        draft.isManualRegionEntry = false
        draft.passphrase = ""
        draft.privateKeyPEM = ""
        validationErrors = [:]
        errorMessage = nil
        regionError = nil

        do {
            if let secrets = try keychainService.loadSecrets(for: profile.id) {
                draft.privateKeyPEM = secrets.privateKeyPEM
                draft.passphrase = secrets.passphrase ?? ""
            } else if !draft.privateKeyPath.isEmpty {
                draft.privateKeyPEM = try String(contentsOfFile: draft.privateKeyPath)
            }
            connectionStatus = L10n.string("auth.profile.loaded")
        } catch {
            errorMessage = AppError.from(error).localizedDescription
        }
    }

    var selectedProfile: AuthProfile? {
        profiles.first(where: { $0.id == draft.selectedProfileID })
    }

    var hasProfiles: Bool {
        !profiles.isEmpty
    }

    var isPresentingProfileEditor: Bool {
        mode != .selectingProfile
    }

    var editorTitle: String {
        mode == .editingProfile ? L10n.string("auth.editor.edit_title") : L10n.string("auth.editor.new_title")
    }

    var selectedProfileSummary: [(String, String)] {
        guard let profile = selectedProfile else { return [] }
        return [
            (L10n.string("common.region"), profile.region),
            (L10n.string("common.method"), profile.method.displayName),
            ("Tenancy", abbreviated(profile.tenancyOCID))
        ]
    }

    let commonRegions = [
        "sa-saopaulo-1",
        "us-ashburn-1",
        "us-phoenix-1",
        "eu-frankfurt-1",
        "eu-amsterdam-1",
        "uk-london-1"
    ]

    var hasLoadedRegions: Bool {
        !regions.isEmpty
    }

    func chooseProfile(id: UUID?) {
        let profile = profiles.first(where: { $0.id == id })
        selectProfile(profile)
    }

    func startCreatingProfile() {
        draft = AuthenticationDraft()
        mode = .creatingProfile
        errorMessage = nil
        regionError = nil
        regions = []
        connectionStatus = nil
        validationErrors = [:]
    }

    func startEditingSelectedProfile() {
        guard let profile = selectedProfile else { return }
        selectProfile(profile)
        mode = .editingProfile
        Task { await loadSubscribedRegionsIfPossible() }
    }

    func dismissProfileEditor() {
        mode = .selectingProfile
        validationErrors = [:]
        errorMessage = nil
        regionError = nil
        if let selectedProfile {
            selectProfile(selectedProfile)
        } else if let firstProfile = profiles.first {
            selectProfile(firstProfile)
        }
    }

    func saveProfile() {
        errorMessage = nil
        do {
            let (profile, _) = try buildProfileAndConfig()
            let savedProfile = try persistProfile(profile)
            loadProfiles()
            selectProfile(savedProfile)
            connectionStatus = L10n.string("auth.profile.saved")
            mode = .selectingProfile
        } catch {
            errorMessage = AppError.from(error).localizedDescription
        }
    }

    func importPrivateKey() {
        guard let url = NativeDialogs.choosePrivateKeyFile() else { return }
        do {
            draft.privateKeyPath = url.path
            draft.privateKeyPEM = try String(contentsOf: url)
            validationErrors[.privateKey] = nil
        } catch {
            errorMessage = AppError.from(error).localizedDescription
        }
    }

    func duplicateSelectedProfile() {
        guard let profile = profiles.first(where: { $0.id == draft.selectedProfileID }) else { return }
        let duplicated = AuthProfile(
            name: profile.name + L10n.string("auth.profile.copy_suffix"),
            method: profile.method,
            tenancyOCID: profile.tenancyOCID,
            userOCID: profile.userOCID,
            fingerprint: profile.fingerprint,
            region: profile.region,
            namespace: profile.namespace,
            defaultCompartmentOCID: profile.defaultCompartmentOCID,
            privateKeyPathHint: profile.privateKeyPathHint,
            rememberMe: profile.rememberMe
        )
        do {
            try profileStore.upsert(duplicated)
            try keychainService.duplicateSecrets(from: profile.id, to: duplicated.id)
            loadProfiles()
            selectProfile(duplicated)
            mode = .selectingProfile
        } catch {
            errorMessage = AppError.from(error).localizedDescription
        }
    }

    func deleteSelectedProfile() {
        guard let profileID = draft.selectedProfileID else { return }
        guard NativeDialogs.confirm(
            title: L10n.string("auth.profile.remove.title"),
            message: L10n.string("auth.profile.remove.message"),
            primary: L10n.string("auth.remove_profile")
        ) else {
            return
        }
        do {
            try profileStore.deleteProfile(id: profileID)
            try keychainService.deleteSecrets(for: profileID)
            loadProfiles()
            if let firstProfile = profiles.first {
                selectProfile(firstProfile)
            } else {
                selectProfile(nil)
            }
        } catch {
            errorMessage = AppError.from(error).localizedDescription
        }
    }

    func testConnection() async {
        isTestingConnection = true
        errorMessage = nil
        defer { isTestingConnection = false }

        do {
            let (_, config) = try buildProfileAndConfig()
            let result = try await objectStorageService.testConnection(using: config)
            connectionStatus = L10n.string("auth.connection.namespace", result.message, result.resolvedNamespace)
            await loadSubscribedRegions(using: config)
        } catch {
            errorMessage = AppError.from(error).localizedDescription
            connectionStatus = nil
        }
    }

    func loadSubscribedRegionsIfPossible() async {
        guard draft.tenancyOCID.trimmed.count > 10,
              draft.userOCID.trimmed.count > 10,
              !draft.fingerprint.trimmed.isEmpty,
              (!draft.privateKeyPEM.trimmed.isEmpty || !draft.privateKeyPath.trimmed.isEmpty) else {
            return
        }

        do {
            let (_, config) = try buildProfileAndConfig()
            await loadSubscribedRegions(using: config)
        } catch {
            regionError = nil
        }
    }

    func enableManualRegionEntry() {
        draft.isManualRegionEntry = true
    }

    func useAutomaticRegionList() {
        draft.isManualRegionEntry = false
    }

    func connect() async throws -> ExplorerSession {
        isConnecting = true
        errorMessage = nil
        connectionStatus = nil
        defer { isConnecting = false }

        let (profile, config) = try buildProfileAndConfig()
        let connection = try await objectStorageService.testConnection(using: config)

        var connectedProfile = profile
        connectedProfile.namespace = connection.resolvedNamespace
        connectedProfile.updatedAt = .now

        let connectedAuth = OCIAuthenticationConfig(
            tenancyOCID: config.tenancyOCID,
            userOCID: config.userOCID,
            fingerprint: config.fingerprint,
            region: config.region,
            namespace: connection.resolvedNamespace,
            compartmentOCID: config.compartmentOCID,
            privateKeyPEM: config.privateKeyPEM,
            passphrase: config.passphrase
        )

        if draft.rememberMe {
            do {
                try persistProfile(connectedProfile)
                loadProfiles()
            } catch {
                let appError = AppError.from(error)
                logger.log(
                    .warning,
                    category: "Auth",
                    message: L10n.string("auth.log.session_started_profile_not_saved"),
                    metadata: [
                        "profile": connectedProfile.name,
                        "error": appError.localizedDescription
                    ]
                )
                connectionStatus = L10n.string("auth.connection.persist_warning", connection.message)
            }
        }

        if connectionStatus == nil {
            connectionStatus = connection.message
        }
        logger.log(.info, category: "Auth", message: L10n.string("auth.log.session_started"), metadata: ["profile": connectedProfile.name])

        return ExplorerSession(profile: connectedProfile, auth: connectedAuth, connection: connection)
    }

    private func buildProfileAndConfig() throws -> (AuthProfile, OCIAuthenticationConfig) {
        validationErrors = validateDraft()
        guard validationErrors.isEmpty else {
            throw AppError.validation(L10n.string("auth.validation.review_fields"))
        }

        if draft.privateKeyPEM.trimmed.isEmpty, !draft.privateKeyPath.trimmed.isEmpty {
            draft.privateKeyPEM = try String(contentsOfFile: draft.privateKeyPath)
        }

        let profile = AuthProfile(
            id: draft.selectedProfileID ?? UUID(),
            name: draft.profileName,
            method: draft.method,
            tenancyOCID: draft.tenancyOCID,
            userOCID: draft.userOCID,
            fingerprint: draft.fingerprint,
            region: draft.region,
            namespace: draft.namespace.nilIfBlank,
            defaultCompartmentOCID: draft.defaultCompartmentOCID.nilIfBlank ?? draft.tenancyOCID,
            privateKeyPathHint: draft.privateKeyPath.nilIfBlank,
            rememberMe: draft.rememberMe,
            createdAt: .now,
            updatedAt: .now
        )

        let config = OCIAuthenticationConfig(
            tenancyOCID: draft.tenancyOCID,
            userOCID: draft.userOCID,
            fingerprint: draft.fingerprint,
            region: draft.region,
            namespace: draft.namespace.nilIfBlank,
            compartmentOCID: draft.defaultCompartmentOCID.nilIfBlank ?? draft.tenancyOCID,
            privateKeyPEM: draft.privateKeyPEM,
            passphrase: draft.passphrase.nilIfBlank
        )
        return (profile, config)
    }

    private func loadSubscribedRegions(using config: OCIAuthenticationConfig) async {
        isLoadingRegions = true
        regionError = nil
        defer { isLoadingRegions = false }

        do {
            let loaded = try await identityService.listSubscribedRegions(using: config)
            regions = loaded
            if let matching = loaded.first(where: { $0.regionCode == draft.region }) {
                draft.region = matching.regionCode
            } else if let first = loaded.first {
                draft.region = first.regionCode
            }
        } catch {
            regions = []
            regionError = L10n.string("auth.region.load_failed")
            draft.isManualRegionEntry = true
        }
    }

    private func validateDraft() -> [AuthenticationField: String] {
        var errors: [AuthenticationField: String] = [:]

        if let message = validationMessage(for: { try Validators.validateRequired(draft.profileName, fieldName: L10n.string("auth.field.profile_name")) }) {
            errors[.profileName] = message
        }
        if let message = validationMessage(for: { try Validators.validateOCID(draft.tenancyOCID, fieldName: L10n.string("auth.field.tenancy_ocid")) }) {
            errors[.tenancyOCID] = message
        }
        if let message = validationMessage(for: { try Validators.validateOCID(draft.userOCID, fieldName: L10n.string("auth.field.user_ocid")) }) {
            errors[.userOCID] = message
        }
        if let message = validationMessage(for: { try Validators.validateRequired(draft.fingerprint, fieldName: L10n.string("auth.field.fingerprint")) }) {
            errors[.fingerprint] = message
        }
        if let message = validationMessage(for: { try Validators.validateRequired(draft.region, fieldName: L10n.string("common.region")) }) {
            errors[.region] = message
        }
        if draft.privateKeyPEM.trimmed.isEmpty, draft.privateKeyPath.trimmed.isEmpty {
            errors[.privateKey] = L10n.string("auth.validation.private_key_required")
        }

        return errors
    }

    private func validationMessage(for validation: () throws -> Void) -> String? {
        do {
            try validation()
            return nil
        } catch {
            return AppError.from(error).localizedDescription
        }
    }

    @discardableResult
    private func persistProfile(_ profile: AuthProfile) throws -> AuthProfile {
        var profileToSave = profile
        profileToSave.updatedAt = .now

        try profileStore.upsert(profileToSave)
        if draft.rememberMe {
            try keychainService.storeSecrets(
                AuthProfileSecrets(privateKeyPEM: draft.privateKeyPEM, passphrase: draft.passphrase.nilIfBlank),
                for: profileToSave.id
            )
        } else {
            try keychainService.deleteSecrets(for: profileToSave.id)
        }
        return profileToSave
    }

    private func abbreviated(_ value: String, prefix: Int = 18, suffix: Int = 8) -> String {
        let trimmed = value.trimmed
        guard trimmed.count > prefix + suffix + 3 else { return trimmed }
        let start = trimmed.prefix(prefix)
        let end = trimmed.suffix(suffix)
        return "\(start)...\(end)"
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
