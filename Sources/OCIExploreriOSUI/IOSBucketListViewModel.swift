import Foundation
import OCIExplorerCore
import OCIExplorerServices
import OCIExplorerShared

@MainActor
final class IOSBucketListViewModel: ObservableObject {
    @Published var buckets: [BucketSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    let session: ExplorerSession
    private let service: OCIObjectStorageServiceProtocol
    private let logger: AppLogger

    init(session: ExplorerSession, service: OCIObjectStorageServiceProtocol, logger: AppLogger) {
        self.session = session
        self.service = service
        self.logger = logger
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            buckets = try await service.listBuckets(using: session.auth)
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            let appError = AppError.from(error)
            errorMessage = appError.localizedDescription
            logger.log(.error, category: "iOSBuckets", message: "Falha ao listar buckets", metadata: ["error": appError.localizedDescription])
        }
    }
}
