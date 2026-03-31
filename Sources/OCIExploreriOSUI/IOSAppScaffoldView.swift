import SwiftUI
import OCIExplorerShared

public struct IOSAppScaffoldView: View {
    @StateObject private var viewModel: IOSAppViewModel

    public init(container: AppContainer = AppContainer()) {
        _viewModel = StateObject(wrappedValue: IOSAppViewModel(container: container))
    }

    public var body: some View {
        Group {
            if viewModel.session == nil {
                IOSAuthenticationView(viewModel: viewModel.authenticationViewModel) { session in
                    await viewModel.startSession(session)
                }
            } else if let bucketViewModel = viewModel.bucketListViewModel {
                IOSBucketListView(viewModel: bucketViewModel) {
                    viewModel.disconnect()
                }
            } else {
                ProgressView("Preparando sessão…")
            }
        }
    }
}
