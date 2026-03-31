import Foundation
import OCIExplorerCore
import OCIExplorerServices
import OCIExplorerShared

@MainActor
final class IOSAuthenticationViewModel: ObservableObject {
    @Published var profiles: [AuthProfile] = []
    @Published var selectedProfileID: UUID?
    @Published var profileName = "Perfil OCI"
    @Published var tenancyOCID = ""
    @Published var userOCID = ""
    @Published var fingerprint = ""
    @Published var regionCode = OCIRegionCatalog.fallbackRegionCode
    @Published var namespace = ""
    @Published var compartmentOCID = ""
    @Published var privateKeyPEM = ""
    @Published var passphrase = ""
    @Published var rememberMe = true
    @Published var isConnecting = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?

    let availableRegions = OCIRegionCatalog.allRegions

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        loadProfiles()
    }

    func loadProfiles() {
        do {
            profiles = try container.profileStore.loadProfiles()
            if selectedProfileID == nil, let first = profiles.first {
                apply(profile: first)
            }
        } catch {
            errorMessage = AppError.from(error).localizedDescription
        }
    }

    func selectProfile(id: UUID) {
        guard let profile = profiles.first(where: { $0.id == id }) else { return }
        apply(profile: profile)
    }

    func connect() async throws -> ExplorerSession {
        isConnecting = true
        errorMessage = nil
        statusMessage = nil
        defer { isConnecting = false }

        let (profile, config) = try buildProfileAndConfig()
        let connection = try await container.objectStorageService.testConnection(using: config)

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

        if rememberMe {
            do {
                try persistProfile(connectedProfile)
            } catch {
                container.logger.log(
                    .warning,
                    category: "iOSAuth",
                    message: "Sessão iniciada, mas o perfil não pôde ser salvo",
                    metadata: ["error": AppError.from(error).localizedDescription]
                )
            }
        }

        namespace = connection.resolvedNamespace
        statusMessage = connection.message
        container.logger.log(.info, category: "iOSAuth", message: "Sessão OCI iniciada", metadata: ["profile": connectedProfile.name])
        return ExplorerSession(profile: connectedProfile, auth: connectedAuth, connection: connection)
    }

    func resetForReconnect() {
        statusMessage = nil
        errorMessage = nil
        loadProfiles()
    }

    private func apply(profile: AuthProfile) {
        selectedProfileID = profile.id
        profileName = profile.name
        tenancyOCID = profile.tenancyOCID
        userOCID = profile.userOCID
        fingerprint = profile.fingerprint
        regionCode = profile.region
        namespace = profile.namespace ?? ""
        compartmentOCID = profile.defaultCompartmentOCID ?? ""
        rememberMe = profile.rememberMe
        passphrase = ""
        privateKeyPEM = ""
        errorMessage = nil
        statusMessage = "Perfil carregado."

        do {
            if let secrets = try container.keychainService.loadSecrets(for: profile.id) {
                privateKeyPEM = secrets.privateKeyPEM
                passphrase = secrets.passphrase ?? ""
            }
        } catch {
            errorMessage = AppError.from(error).localizedDescription
        }
    }

    private func buildProfileAndConfig() throws -> (AuthProfile, OCIAuthenticationConfig) {
        try Validators.validateRequired(profileName, fieldName: "Nome do perfil")
        try Validators.validateOCID(tenancyOCID, fieldName: "Tenancy OCID")
        try Validators.validateOCID(userOCID, fieldName: "User OCID")
        try Validators.validateRequired(fingerprint, fieldName: "Fingerprint")
        try Validators.validateRequired(regionCode, fieldName: "Região")
        try Validators.validateRequired(privateKeyPEM, fieldName: "Chave privada PEM")

        let trimmedCompartment = compartmentOCID.trimmed.nilIfBlank ?? tenancyOCID.trimmed
        let profile = AuthProfile(
            id: selectedProfileID ?? UUID(),
            name: profileName.trimmed,
            method: .apiKey,
            tenancyOCID: tenancyOCID.trimmed,
            userOCID: userOCID.trimmed,
            fingerprint: fingerprint.trimmed,
            region: regionCode,
            namespace: namespace.trimmed.nilIfBlank,
            defaultCompartmentOCID: trimmedCompartment,
            privateKeyPathHint: nil,
            rememberMe: rememberMe,
            createdAt: .now,
            updatedAt: .now
        )

        let config = OCIAuthenticationConfig(
            tenancyOCID: tenancyOCID.trimmed,
            userOCID: userOCID.trimmed,
            fingerprint: fingerprint.trimmed,
            region: regionCode,
            namespace: namespace.trimmed.nilIfBlank,
            compartmentOCID: trimmedCompartment,
            privateKeyPEM: privateKeyPEM.trimmed,
            passphrase: passphrase.trimmed.nilIfBlank
        )

        return (profile, config)
    }

    private func persistProfile(_ profile: AuthProfile) throws {
        try container.profileStore.upsert(profile)
        try container.keychainService.storeSecrets(
            AuthProfileSecrets(
                privateKeyPEM: privateKeyPEM.trimmed,
                passphrase: passphrase.trimmed.nilIfBlank
            ),
            for: profile.id
        )
        loadProfiles()
        selectedProfileID = profile.id
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfBlank: String? {
        trimmed.isEmpty ? nil : trimmed
    }
}
