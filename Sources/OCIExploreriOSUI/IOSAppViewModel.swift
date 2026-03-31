import Foundation
import OCIExplorerShared

@MainActor
final class IOSAppViewModel: ObservableObject {
    @Published var session: ExplorerSession?
    @Published var authenticationViewModel: IOSAuthenticationViewModel
    @Published var bucketListViewModel: IOSBucketListViewModel?

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        self.authenticationViewModel = IOSAuthenticationViewModel(container: container)
    }

    func startSession(_ session: ExplorerSession) async {
        self.session = session
        let bucketViewModel = IOSBucketListViewModel(
            session: session,
            service: container.objectStorageService,
            logger: container.logger
        )
        self.bucketListViewModel = bucketViewModel
        await bucketViewModel.refresh()
    }

    func disconnect() {
        session = nil
        bucketListViewModel = nil
        authenticationViewModel.resetForReconnect()
    }
}
