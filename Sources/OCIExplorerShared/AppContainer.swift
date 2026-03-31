import Foundation
import OCIExplorerCore
import OCIExplorerServices

public struct ExplorerSession: Sendable {
    public let profile: AuthProfile
    public let auth: OCIAuthenticationConfig
    public let connection: ConnectionTestResult

    public init(profile: AuthProfile, auth: OCIAuthenticationConfig, connection: ConnectionTestResult) {
        self.profile = profile
        self.auth = auth
        self.connection = connection
    }
}

@MainActor
public final class AppContainer {
    public let logger: AppLogger
    public let profileStore: ProfileStoreProtocol
    public let keychainService: KeychainServiceProtocol
    public let objectStorageService: OCIObjectStorageServiceProtocol
    public let identityService: OCIIdentityServiceProtocol
    public let parHistoryStore: PARHistoryStoreProtocol

    public init() {
        let logger = AppLogger()
        let httpClient = OCIHTTPClient(logger: logger)
        let signer = OCIRequestSigner()
        self.logger = logger
        self.profileStore = ProfileStore()
        self.keychainService = KeychainService()
        self.parHistoryStore = PARHistoryStore()
        self.objectStorageService = OCIObjectStorageService(
            signer: signer,
            httpClient: httpClient,
            logger: logger
        )
        self.identityService = OCIIdentityService(
            signer: signer,
            httpClient: httpClient,
            logger: logger
        )
    }

    public func makeTransferCoordinator(auth: OCIAuthenticationConfig) -> TransferCoordinator {
        TransferCoordinator(service: objectStorageService, auth: auth, logger: logger)
    }
}
