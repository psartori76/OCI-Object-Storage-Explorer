import Combine
import Foundation
import OCIExplorerCore
import OCIExplorerShared
import OCIExplorerServices

enum ExplorerContentState: Equatable {
    case idle
    case loading
    case empty
    case loaded
    case error
}

struct ExplorerBanner: Equatable {
    let title: String
    let message: String?
    let isError: Bool
}

enum ObjectVersionsState: Equatable {
    case idle
    case loading
    case disabled
    case empty
    case loaded
    case error(String)
}

enum ObjectDetailsState: Equatable {
    case idle
    case loading
    case loaded
    case failed
}

@MainActor
final class ExplorerViewModel: ObservableObject {
    @Published var buckets: [BucketSummary] = []
    @Published var availableRegions: [OCIRegion] = []
    @Published var selectedRegionCode: String
    @Published var selectedBucketID: String?
    @Published var selectedItemIDs: Set<String> = []
    @Published var selectedObjects: [ObjectBrowserItem] = []
    @Published var currentPrefix = ""
    @Published var items: [ObjectBrowserItem] = []
    @Published var bucketDetails: BucketDetails?
    @Published var selectedObjectMetadata: ObjectMetadata?
    @Published var searchText = ""
    @Published var isLoadingBuckets = false
    @Published var isLoadingObjects = false
    @Published var toastMessage: String?
    @Published var banner: ExplorerBanner?
    @Published var contentState: ExplorerContentState = .idle
    @Published var objectDetailsState: ObjectDetailsState = .idle
    @Published var objectDetailsError: String?
    @Published var objectVersions: [ObjectVersionSummary] = []
    @Published var objectVersionsState: ObjectVersionsState = .idle
    @Published var objectVersionsError: String?
    @Published var isShowingVersionsSheet = false
    @Published var versionsTargetObjectName: String?

    let session: ExplorerSession
    let transferCoordinator: TransferCoordinator

    private let service: OCIObjectStorageServiceProtocol
    private let parHistoryStore: PARHistoryStoreProtocol
    private let logger: AppLogger
    private var cancellables: Set<AnyCancellable> = []
    private var handledTransferStatuses: [UUID: TransferStatus] = [:]
    private var metadataRequestID = UUID()
    private var contentRequestID = UUID()

    init(
        session: ExplorerSession,
        service: OCIObjectStorageServiceProtocol,
        parHistoryStore: PARHistoryStoreProtocol,
        transferCoordinator: TransferCoordinator,
        logger: AppLogger
    ) {
        self.session = session
        self.service = service
        self.parHistoryStore = parHistoryStore
        self.transferCoordinator = transferCoordinator
        self.logger = logger
        self.selectedRegionCode = Self.resolvedInitialRegion(from: session.auth.region)
        self.availableRegions = Self.makeRegionList(selectedRegionCode: self.selectedRegionCode)
        observeTransferQueue()
    }

    var diagnosticLogger: AppLogger {
        logger
    }

    func makePARManagementViewModel() -> PARManagementViewModel? {
        guard let bucketName = selectedBucket?.name else { return nil }
        let selectedObject = canCreatePARForSelection ? selectedFileItems.first?.fullPath : nil
        return PARManagementViewModel(
            bucketName: bucketName,
            selectedObjectName: selectedObject,
            auth: currentAuth,
            service: service,
            historyStore: parHistoryStore,
            logger: logger
        )
    }

    var currentAuth: OCIAuthenticationConfig {
        var auth = session.auth
        auth.region = selectedRegionCode
        return auth
    }

    var currentRegionDisplayName: String {
        Self.displayName(for: selectedRegionCode)
    }

    var selectedBucket: BucketSummary? {
        buckets.first(where: { $0.id == selectedBucketID || $0.name == selectedBucketID })
    }

    var filteredItems: [ObjectBrowserItem] {
        guard !searchText.isEmpty else { return items }
        return items.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) || $0.fullPath.localizedCaseInsensitiveContains(searchText)
        }
    }

    var selectedItems: [ObjectBrowserItem] {
        selectedObjects
    }

    var selectedFileItems: [ObjectBrowserItem] {
        selectedObjects.filter { !$0.isFolder }
    }

    var selectedObject: ObjectBrowserItem? {
        guard selectedFileItems.count == 1 else { return nil }
        return selectedFileItems.first
    }

    var breadcrumbs: [String] {
        currentPrefix
            .split(separator: "/")
            .map(String.init)
    }

    var currentLocationTitle: String {
        selectedBucket?.name ?? L10n.string("explorer.navigation.title")
    }

    var currentSearchPlaceholder: String {
        L10n.string("explorer.search.placeholder")
    }

    var canDownloadSelection: Bool {
        !selectedFileItems.isEmpty
    }

    var canDeleteSelection: Bool {
        !selectedFileItems.isEmpty
    }

    var canCreatePARForSelection: Bool {
        selectedFileItems.count == 1
    }

    var canShowVersionsForSelection: Bool {
        selectedFileItems.count == 1
    }

    var selectedPrimaryItem: ObjectBrowserItem? {
        selectedObjects.first
    }

    var isBucketVersioningEnabled: Bool {
        let value = bucketDetails?.versioning?.lowercased() ?? ""
        return value.contains("enabled")
    }

    var selectedObjectVersionsCountText: String {
        guard selectedObject != nil else { return L10n.string("common.not_available") }
        if versionsTargetObjectName != selectedObject?.fullPath {
            return isBucketVersioningEnabled ? L10n.string("explorer.value.load_to_view") : L10n.string("common.disabled")
        }
        switch objectVersionsState {
        case .disabled:
            return L10n.string("common.disabled")
        case .empty:
            return L10n.string("explorer.value.no_previous_versions")
        case .loaded:
            return L10n.plural("count.object_versions", count: objectVersions.count)
        case .loading:
            return L10n.string("common.loading")
        case .error:
            return L10n.string("explorer.value.unavailable")
        case .idle:
            return L10n.string("common.not_available")
        }
    }

    var emptyStateTitle: String {
        if buckets.isEmpty {
            return L10n.string("explorer.region.empty.title")
        }
        if !searchText.isEmpty {
            return L10n.string("explorer.empty.no_results.title")
        }
        if currentPrefix.isEmpty {
            return L10n.string("explorer.empty.bucket_empty.title")
        }
        return L10n.string("explorer.empty.folder_empty.title")
    }

    var emptyStateMessage: String {
        if buckets.isEmpty {
            return L10n.string("explorer.empty.no_buckets.message")
        }
        if !searchText.isEmpty {
            return L10n.string("explorer.empty.no_results.message")
        }
        if currentPrefix.isEmpty {
            return L10n.string("explorer.empty.bucket_empty.message")
        }
        return L10n.string("explorer.empty.folder_empty.message")
    }

    func bootstrap() async {
        await refreshBuckets()
    }

    func changeRegion(to regionCode: String) async {
        let normalized = Self.resolvedInitialRegion(from: regionCode)
        guard !normalized.isEmpty else { return }
        guard normalized != selectedRegionCode else { return }

        selectedRegionCode = normalized
        availableRegions = Self.makeRegionList(selectedRegionCode: normalized)
        transferCoordinator.updateAuth(currentAuth)
        resetRegionScopedState()
        await refreshBuckets()
    }

    func refreshBuckets() async {
        isLoadingBuckets = true
        contentState = buckets.isEmpty ? .loading : contentState
        defer { isLoadingBuckets = false }

        do {
            clearBanner()
            buckets = try await service.listBuckets(using: currentAuth)
            if let selectedBucketID,
               !buckets.contains(where: { $0.id == selectedBucketID || $0.name == selectedBucketID }) {
                self.selectedBucketID = nil
            }
            guard !buckets.isEmpty else {
                resetBucketContentStateForEmptyRegion()
                contentState = .empty
                return
            }
            if self.selectedBucketID == nil {
                selectedBucketID = buckets.first?.id
            }
            if let selectedBucket = selectedBucket {
                let requestID = beginContentRequest()
                try await loadBucket(named: selectedBucket.name, requestID: requestID)
            } else {
                contentState = .empty
            }
        } catch {
            handle(error, context: .loadBuckets)
        }
    }

    func selectBucket(id: String?) async {
        selectedBucketID = id
        currentPrefix = ""
        selectedItemIDs = []
        selectedObjects = []
        selectedObjectMetadata = nil
        objectDetailsState = .idle
        objectDetailsError = nil
        objectVersions = []
        objectVersionsState = .idle
        objectVersionsError = nil
        versionsTargetObjectName = nil
        bucketDetails = nil
        clearBanner()
        guard let selectedBucket = selectedBucket else { return }
        let requestID = beginContentRequest()
        do {
            try await loadBucket(named: selectedBucket.name, requestID: requestID)
        } catch {
            guard isCurrentContentRequest(requestID) else { return }
            handle(error, context: .loadObjects)
        }
    }

    func navigate(to item: ObjectBrowserItem) async {
        if item.isFolder {
            currentPrefix = item.fullPath
            await refreshCurrentPrefix()
        } else {
            await loadMetadata(for: item)
        }
    }

    func navigateToRoot() async {
        currentPrefix = ""
        await refreshCurrentPrefix()
    }

    func navigateToBreadcrumb(index: Int) async {
        let prefix = breadcrumbs.prefix(index + 1).joined(separator: "/")
        currentPrefix = prefix.isEmpty ? "" : prefix + "/"
        await refreshCurrentPrefix()
    }

    func refreshCurrentPrefix() async {
        guard let bucketName = selectedBucket?.name else { return }
        let requestID = beginContentRequest()
        do {
            try await loadObjects(bucketName: bucketName, prefix: currentPrefix, requestID: requestID)
        } catch {
            guard isCurrentContentRequest(requestID) else { return }
            handle(error, context: .loadObjects)
        }
    }

    func loadMetadataForSelection() async {
        guard selectedFileItems.count == 1, let item = selectedFileItems.first else {
            selectedObjectMetadata = nil
            objectDetailsState = .idle
            objectDetailsError = nil
            return
        }
        await loadMetadata(for: item)
    }

    func updateSelection(_ newSelection: Set<String>) {
        clearObjectDetailError()
        selectedItemIDs = newSelection
        syncSelectedObjects()

        let selected = selectedPrimaryItem
        if selectedFileItems.count != 1 || selected?.isFolder == true {
            selectedObjectMetadata = nil
            objectDetailsState = .idle
            objectDetailsError = nil
        }

        if selectedFileItems.count != 1 || selected?.fullPath != versionsTargetObjectName {
            objectVersions = []
            objectVersionsState = .idle
            objectVersionsError = nil
            versionsTargetObjectName = nil
        }

        Task {
            await loadMetadataForSelection()
        }
    }

    func createBucket(request: CreateBucketRequestModel) async {
        do {
            clearBanner()
            _ = try await service.createBucket(request, using: currentAuth)
            toastMessage = L10n.string("explorer.toast.bucket_created")
            await refreshBuckets()
        } catch {
            handle(error, context: .createBucket)
        }
    }

    func deleteSelectedBucket() async {
        guard let bucket = selectedBucket else { return }
        guard NativeDialogs.confirm(
            title: L10n.string("explorer.confirm.delete_bucket.title", bucket.name),
            message: L10n.string("explorer.confirm.delete_bucket.message"),
            primary: L10n.string("common.delete")
        ) else {
            return
        }
        do {
            try await service.deleteBucket(named: bucket.name, using: currentAuth)
            toastMessage = L10n.string("explorer.toast.bucket_deleted")
            selectedBucketID = nil
            await refreshBuckets()
        } catch {
            handle(error, context: .deleteBucket)
        }
    }

    func deleteSelectedObjects() async {
        guard let bucketName = selectedBucket?.name else { return }
        let objectsToDelete = selectedFileItems
        guard !objectsToDelete.isEmpty else { return }
        let isSingleObject = objectsToDelete.count == 1
        let previewNames = objectsToDelete.prefix(3).map(\.name).joined(separator: ", ")
        guard NativeDialogs.confirm(
            title: isSingleObject ? L10n.string("explorer.confirm.delete_objects.single.title") : L10n.string("explorer.confirm.delete_objects.multiple.title"),
            message: isSingleObject
                ? L10n.string("explorer.confirm.delete_objects.single.message", objectsToDelete[0].name)
                : L10n.string("explorer.confirm.delete_objects.multiple.message", objectsToDelete.count, previewNames, objectsToDelete.count > 3 ? "…" : ""),
            primary: L10n.string("common.delete")
        ) else {
            return
        }

        var deletedIDs = Set<String>()
        var failedCount = 0

        for object in objectsToDelete {
            do {
                try await service.deleteObject(bucketName: bucketName, objectName: object.fullPath, using: currentAuth)
                deletedIDs.insert(object.id)
            } catch {
                failedCount += 1
                logger.log(
                    .error,
                    category: "Explorer",
                    message: "\(ErrorContext.deleteObject.logLabel): \(AppError.from(error).localizedDescription)",
                    metadata: ["object": object.fullPath]
                )
            }
        }

        if !deletedIDs.isEmpty {
            items.removeAll { deletedIDs.contains($0.id) }
            selectedItemIDs.subtract(deletedIDs)
            syncSelectedObjects()
            contentState = items.isEmpty ? .empty : .loaded
        }

        if selectedFileItems.count != 1 {
            selectedObjectMetadata = nil
            objectDetailsState = .idle
            objectDetailsError = nil
            objectVersions = []
            objectVersionsState = .idle
            versionsTargetObjectName = nil
        }

        if failedCount == 0 {
            toastMessage = isSingleObject ? L10n.string("explorer.toast.object_deleted") : L10n.plural("count.objects_deleted_success", count: deletedIDs.count)
        } else if !deletedIDs.isEmpty {
            banner = ExplorerBanner(
                title: L10n.string("explorer.banner.partial_delete.title"),
                message: L10n.string("explorer.banner.partial_delete.message", deletedIDs.count, failedCount),
                isError: true
            )
        } else {
            handle(AppError.network(L10n.string("explorer.error.delete_selected_objects")), context: .deleteObject, affectsContentState: false)
        }
    }

    func queueUploads() async {
        let files = NativeDialogs.chooseFiles()
        await queueUploads(from: files)
    }

    func queueUploads(from fileURLs: [URL]) async {
        guard let bucketName = selectedBucket?.name else { return }
        let files = fileURLs.filter(\.isFileURL)
        guard !files.isEmpty else { return }
        let existingPaths = Set(items.map(\.fullPath))
        var queuedCount = 0

        for fileURL in files {
            let objectName = currentPrefix + fileURL.lastPathComponent
            if existingPaths.contains(objectName) {
                let overwrite = NativeDialogs.confirm(
                    title: L10n.string("explorer.confirm.overwrite_object.title", fileURL.lastPathComponent),
                    message: L10n.string("explorer.confirm.overwrite_object.message"),
                    primary: L10n.string("dialog.name_conflict.overwrite")
                )
                if !overwrite { continue }
            }
            transferCoordinator.upload(
                fileURL: fileURL,
                bucketName: bucketName,
                objectName: objectName,
                contentType: inferredContentType(for: fileURL)
            )
            queuedCount += 1
        }
        if queuedCount > 0 {
            toastMessage = L10n.plural("count.uploads_started", count: queuedCount)
        }
    }

    func createFolder(named folderName: String) async {
        guard let bucketName = selectedBucket?.name else { return }
        let trimmedName = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: tempURL.path, contents: Data())

        do {
            defer { try? FileManager.default.removeItem(at: tempURL) }
            let objectName = currentPrefix + trimmedName + "/"
            try await service.uploadObject(
                bucketName: bucketName,
                objectName: objectName,
                fileURL: tempURL,
                contentType: "application/x-directory",
                using: currentAuth
            ) { _ in }
            toastMessage = L10n.string("explorer.toast.virtual_folder_created")
            await refreshCurrentPrefix()
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            handle(error, context: .createFolder)
        }
    }

    func queueDownloads() async {
        guard let bucketName = selectedBucket?.name else { return }
        let objects = selectedFileItems
        guard !objects.isEmpty else { return }
        guard let directory = NativeDialogs.chooseDirectory(prompt: L10n.string("dialog.download.choose_destination")) else { return }

        for item in objects {
            guard let destination = NativeDialogs.resolveDownloadDestination(
                fileName: URL(fileURLWithPath: item.fullPath).lastPathComponent,
                destinationDirectory: directory
            ) else {
                continue
            }
            transferCoordinator.download(bucketName: bucketName, objectName: item.fullPath, destinationURL: destination)
        }
        toastMessage = L10n.plural("count.downloads_added_queue", count: objects.count)
    }

    func showVersionsForSelectedObject() async {
        guard canShowVersionsForSelection, let selectedObject else { return }
        versionsTargetObjectName = selectedObject.fullPath
        isShowingVersionsSheet = true

        guard isBucketVersioningEnabled else {
            objectVersions = []
            objectVersionsState = .disabled
            objectVersionsError = nil
            return
        }

        objectVersionsState = .loading
        objectVersionsError = nil
        do {
            let versions = try await service.listObjectVersions(
                bucketName: selectedBucket?.name ?? "",
                objectName: selectedObject.fullPath,
                using: currentAuth
            )
            objectVersions = versions
            objectVersionsState = versions.isEmpty ? .empty : .loaded
        } catch {
            objectVersions = []
            objectVersionsError = L10n.string("explorer.error.object_versions")
            objectVersionsState = .error(objectVersionsError ?? L10n.string("explorer.error.object_versions"))
            logger.log(.warning, category: "Explorer", message: L10n.string("explorer.log.object_versions"), metadata: ["object": selectedObject.fullPath, "error": AppError.from(error).localizedDescription])
        }
    }

    func copySelectedObjectName() {
        guard !selectedObjects.isEmpty else { return }
        NativeDialogs.copyToPasteboard(selectedObjects.map(\.name).joined(separator: "\n"))
        toastMessage = selectedObjects.count == 1 ? L10n.string("explorer.toast.object_name_copied") : L10n.string("explorer.toast.object_names_copied")
    }

    func copySelectedObjectPath() {
        guard !selectedObjects.isEmpty else { return }
        NativeDialogs.copyToPasteboard(selectedObjects.map(\.fullPath).joined(separator: "\n"))
        toastMessage = selectedObjects.count == 1 ? L10n.string("explorer.toast.object_path_copied") : L10n.string("explorer.toast.object_paths_copied")
    }

    func copySelectedBucketName() {
        guard let bucket = selectedBucket else { return }
        NativeDialogs.copyToPasteboard(bucket.name)
        toastMessage = L10n.string("explorer.toast.bucket_name_copied")
    }

    func clearBanner() {
        banner = nil
    }

    func clearObjectDetailError() {
        objectDetailsError = nil
        if banner?.title == ErrorContext.loadMetadata.userTitle {
            banner = nil
        }
    }

    func retryAfterError() async {
        guard selectedBucket != nil else {
            await refreshBuckets()
            return
        }
        await refreshCurrentPrefix()
    }

    func abbreviated(_ value: String?, prefix: Int = 16, suffix: Int = 8) -> String {
        guard let value else { return L10n.string("common.not_available") }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > prefix + suffix + 3 else { return trimmed }
        return "\(trimmed.prefix(prefix))...\(trimmed.suffix(suffix))"
    }

    private func loadBucket(named bucketName: String, requestID: UUID) async throws {
        contentState = .loading
        let previousSelection = selectedItemIDs
        let requestedPrefix = currentPrefix
        async let details = service.getBucketDetails(named: bucketName, using: currentAuth)
        async let listing = service.listObjects(bucketName: bucketName, prefix: requestedPrefix, using: currentAuth, start: nil)
        let loadedDetails = try await details
        let page = try await listing
        guard isCurrentContentRequest(requestID),
              selectedBucket?.name == bucketName,
              currentPrefix == requestedPrefix else { return }
        bucketDetails = loadedDetails
        items = page.items
        selectedItemIDs = previousSelection.intersection(Set(page.items.map(\.id)))
        syncSelectedObjects()
        contentState = page.items.isEmpty ? .empty : .loaded
        if let selectedObject {
            await loadMetadata(for: selectedObject)
        } else {
            selectedObjectMetadata = nil
            objectDetailsState = .idle
            objectDetailsError = nil
        }
    }

    private func loadObjects(bucketName: String, prefix: String, requestID: UUID) async throws {
        isLoadingObjects = true
        contentState = .loading
        defer { isLoadingObjects = false }
        let previousSelection = selectedItemIDs
        let page = try await service.listObjects(bucketName: bucketName, prefix: prefix, using: currentAuth, start: nil)
        guard isCurrentContentRequest(requestID),
              selectedBucket?.name == bucketName,
              currentPrefix == prefix else { return }
        items = page.items
        selectedItemIDs = previousSelection.intersection(Set(page.items.map(\.id)))
        syncSelectedObjects()
        if let selectedObject {
            await loadMetadata(for: selectedObject)
        } else {
            selectedObjectMetadata = nil
            objectDetailsState = .idle
            objectDetailsError = nil
        }
        contentState = page.items.isEmpty ? .empty : .loaded
    }

    private func loadMetadata(for item: ObjectBrowserItem) async {
        guard let bucketName = selectedBucket?.name else { return }
        let requestID = UUID()
        metadataRequestID = requestID
        objectDetailsState = .loading
        objectDetailsError = nil
        if banner?.title == ErrorContext.loadMetadata.userTitle {
            banner = nil
        }
        do {
            let metadata = try await service.metadataForObject(bucketName: bucketName, objectName: item.fullPath, using: currentAuth)
            guard metadataRequestID == requestID, selectedPrimaryItem?.id == item.id else { return }
            selectedObjectMetadata = metadata
            objectDetailsState = .loaded
            objectDetailsError = nil
            if banner?.title == ErrorContext.loadMetadata.userTitle {
                banner = nil
            }
        } catch {
            guard metadataRequestID == requestID, selectedPrimaryItem?.id == item.id else { return }
            selectedObjectMetadata = nil
            objectDetailsState = .failed
            objectDetailsError = L10n.string("explorer.error.object_details")
            logger.log(.warning, category: "Explorer", message: "\(ErrorContext.loadMetadata.logLabel): \(AppError.from(error).localizedDescription)")
        }
    }

    private func observeTransferQueue() {
        transferCoordinator.$records
            .receive(on: RunLoop.main)
            .sink { [weak self] records in
                guard let self else { return }
                for record in records {
                    let previousStatus = self.handledTransferStatuses[record.id]
                    guard previousStatus != record.status else { continue }
                    self.handledTransferStatuses[record.id] = record.status
                    self.handleTransferStatusChange(record)
                }
            }
            .store(in: &cancellables)
    }

    private func handleTransferStatusChange(_ record: TransferRecord) {
        switch record.status {
        case .queued:
            break
        case .running:
            if record.direction == .upload {
                toastMessage = L10n.string("explorer.toast.upload_running", record.displayName)
            }
        case .completed:
            if record.direction == .upload {
                toastMessage = L10n.string("explorer.toast.upload_completed", record.displayName)
                Task { await refreshAfterUploadCompletion(record) }
            }
        case .failed:
            if record.direction == .upload {
                toastMessage = record.errorMessage ?? L10n.string("explorer.toast.upload_failed")
            }
        case .cancelled:
            if record.direction == .upload {
                toastMessage = L10n.string("explorer.toast.upload_cancelled", record.displayName)
            }
        }
    }

    private func refreshAfterUploadCompletion(_ record: TransferRecord) async {
        guard let currentBucket = selectedBucket?.name,
              let (bucketName, objectName) = parseDestinationPath(record.destinationPath),
              bucketName == currentBucket else { return }

        await refreshCurrentPrefix()

        if objectName.hasPrefix(currentPrefix),
           let uploadedItem = items.first(where: { $0.fullPath == objectName }) {
            selectedItemIDs = [uploadedItem.id]
            syncSelectedObjects()
            await loadMetadata(for: uploadedItem)
        }
    }

    private func parseDestinationPath(_ destinationPath: String) -> (String, String)? {
        guard let slashIndex = destinationPath.firstIndex(of: "/") else { return nil }
        let bucketName = String(destinationPath[..<slashIndex])
        let objectName = String(destinationPath[destinationPath.index(after: slashIndex)...])
        guard !bucketName.isEmpty, !objectName.isEmpty else { return nil }
        return (bucketName, objectName)
    }

    private func inferredContentType(for fileURL: URL) -> String? {
        switch fileURL.pathExtension.lowercased() {
        case "json":
            "application/json"
        case "txt", "log":
            "text/plain"
        case "png":
            "image/png"
        case "jpg", "jpeg":
            "image/jpeg"
        case "pdf":
            "application/pdf"
        default:
            nil
        }
    }

    private func resetRegionScopedState() {
        contentRequestID = UUID()
        buckets = []
        resetBucketContentStateForEmptyRegion()
        contentState = .loading
        clearBanner()
    }

    private func resetBucketContentStateForEmptyRegion() {
        selectedBucketID = nil
        selectedItemIDs = []
        selectedObjects = []
        currentPrefix = ""
        items = []
        bucketDetails = nil
        selectedObjectMetadata = nil
        objectDetailsState = .idle
        objectDetailsError = nil
        objectVersions = []
        objectVersionsState = .idle
        objectVersionsError = nil
        versionsTargetObjectName = nil
    }

    private func beginContentRequest() -> UUID {
        let requestID = UUID()
        contentRequestID = requestID
        return requestID
    }

    private func isCurrentContentRequest(_ requestID: UUID) -> Bool {
        contentRequestID == requestID
    }

    private func syncSelectedObjects() {
        selectedObjects = items.filter { selectedItemIDs.contains($0.id) }
    }

    private static func resolvedInitialRegion(from regionCode: String?) -> String {
        let trimmed = regionCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? OCIRegionCatalog.fallbackRegionCode : trimmed
    }

    private static func makeRegionList(selectedRegionCode: String) -> [OCIRegion] {
        var regions = OCIRegionCatalog.allRegions
        if !regions.contains(where: { $0.regionCode == selectedRegionCode }) {
            regions.append(
                OCIRegion(
                    regionCode: selectedRegionCode,
                    regionKey: selectedRegionCode.uppercased(),
                    regionName: selectedRegionCode,
                    status: "READY",
                    isHomeRegion: false
                )
            )
        }
        return regions.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private static func displayName(for regionCode: String) -> String {
        makeRegionList(selectedRegionCode: regionCode)
            .first(where: { $0.regionCode == regionCode })?
            .displayName ?? regionCode
    }

    private func handle(_ error: Error, context: ErrorContext, affectsContentState: Bool = true) {
        let appError = AppError.from(error)
        logger.log(.error, category: "Explorer", message: "\(context.logLabel): \(appError.localizedDescription)")
        if context != .loadMetadata {
            banner = ExplorerBanner(
                title: context.userTitle,
                message: context.userMessage,
                isError: true
            )
        }
        if affectsContentState, [.loadBuckets, .loadObjects].contains(context) {
            contentState = .error
        }
    }

}

private enum ErrorContext: Equatable {
    case loadBuckets
    case loadObjects
    case loadMetadata
    case createBucket
    case deleteBucket
    case deleteObject
    case createFolder

    var userTitle: String {
        switch self {
        case .loadBuckets:
            return L10n.string("explorer.error.load_buckets.title")
        case .loadObjects:
            return L10n.string("explorer.error.load_objects.title")
        case .loadMetadata:
            return L10n.string("explorer.error.load_metadata.title")
        case .createBucket:
            return L10n.string("explorer.error.create_bucket.title")
        case .deleteBucket:
            return L10n.string("explorer.error.delete_bucket.title")
        case .deleteObject:
            return L10n.string("explorer.error.delete_object.title")
        case .createFolder:
            return L10n.string("explorer.error.create_folder.title")
        }
    }

    var userMessage: String {
        switch self {
        case .loadBuckets:
            return L10n.string("explorer.error.load_buckets.message")
        case .loadObjects:
            return L10n.string("explorer.error.load_objects.context_message")
        case .loadMetadata:
            return L10n.string("explorer.error.load_metadata.message")
        case .createBucket:
            return L10n.string("explorer.error.create_bucket.message")
        case .deleteBucket:
            return L10n.string("explorer.error.delete_bucket.message")
        case .deleteObject:
            return L10n.string("explorer.error.delete_object.message")
        case .createFolder:
            return L10n.string("explorer.error.create_folder.message")
        }
    }

    var logLabel: String {
        switch self {
        case .loadBuckets:
            return L10n.string("explorer.log.load_buckets")
        case .loadObjects:
            return L10n.string("explorer.log.load_objects")
        case .loadMetadata:
            return L10n.string("explorer.log.load_metadata")
        case .createBucket:
            return L10n.string("explorer.log.create_bucket")
        case .deleteBucket:
            return L10n.string("explorer.log.delete_bucket")
        case .deleteObject:
            return L10n.string("explorer.log.delete_object")
        case .createFolder:
            return L10n.string("explorer.log.create_folder")
        }
    }
}
