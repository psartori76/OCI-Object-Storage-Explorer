import Combine
import Foundation
import OCIExplorerCore
import OCIExplorerShared
import OCIExplorerServices

@MainActor
final class AppViewModel: ObservableObject {
    @Published var session: ExplorerSession?
    @Published var authenticationViewModel: AuthenticationViewModel
    @Published var explorerViewModel: ExplorerViewModel?

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        self.authenticationViewModel = AuthenticationViewModel(
            profileStore: container.profileStore,
            keychainService: container.keychainService,
            objectStorageService: container.objectStorageService,
            identityService: container.identityService,
            logger: container.logger
        )
    }

    func connect() async {
        do {
            let session = try await authenticationViewModel.connect()
            let explorerViewModel = ExplorerViewModel(
                session: session,
                service: container.objectStorageService,
                parHistoryStore: container.parHistoryStore,
                transferCoordinator: container.makeTransferCoordinator(auth: session.auth),
                logger: container.logger
            )
            self.session = session
            self.explorerViewModel = explorerViewModel
            await explorerViewModel.bootstrap()
        } catch {
            let appError = AppError.from(error)
            authenticationViewModel.connectionStatus = nil
            authenticationViewModel.errorMessage = appError.localizedDescription
            container.logger.log(.error, category: "App", message: L10n.string("app.log.session_start_failed"), metadata: ["error": appError.localizedDescription])
        }
    }

    func disconnect() {
        session = nil
        explorerViewModel = nil
    }
}
