import Combine
import Foundation
import OCIExplorerCore

public enum TransferReplayDescriptor: Sendable {
    case upload(fileURL: URL, bucketName: String, objectName: String, contentType: String?)
    case download(bucketName: String, objectName: String, destinationURL: URL)
}

@MainActor
public final class TransferCoordinator: ObservableObject {
    @Published public private(set) var records: [TransferRecord] = []

    private let service: OCIObjectStorageServiceProtocol
    private var auth: OCIAuthenticationConfig
    private let logger: AppLogger
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var replayDescriptors: [UUID: TransferReplayDescriptor] = [:]
    private var cancelledRecordIDs: Set<UUID> = []
    private let maxConcurrentTransfers = 2

    public init(service: OCIObjectStorageServiceProtocol, auth: OCIAuthenticationConfig, logger: AppLogger) {
        self.service = service
        self.auth = auth
        self.logger = logger
    }

    public var queuedCount: Int {
        records.filter { $0.status == .queued }.count
    }

    public var runningCount: Int {
        records.filter { $0.status == .running }.count
    }

    public var failedCount: Int {
        records.filter { $0.status == .failed }.count
    }

    public var completedCount: Int {
        records.filter { $0.status == .completed }.count
    }

    public var overallProgress: Double {
        let relevant = records.filter { $0.status == .queued || $0.status == .running }
        guard !relevant.isEmpty else { return 1 }
        let total = relevant.reduce(0) { partial, record in
            partial + max(0, min(1, record.progress))
        }
        return total / Double(relevant.count)
    }

    public var hasActiveTransfers: Bool {
        queuedCount > 0 || runningCount > 0
    }

    public func updateAuth(_ auth: OCIAuthenticationConfig) {
        self.auth = auth
    }

    public func upload(fileURL: URL, bucketName: String, objectName: String, contentType: String?) {
        let record = TransferRecord(
            direction: .upload,
            displayName: fileURL.lastPathComponent,
            sourcePath: fileURL.path,
            destinationPath: "\(bucketName)/\(objectName)"
        )
        enqueue(record, replay: .upload(fileURL: fileURL, bucketName: bucketName, objectName: objectName, contentType: contentType))
    }

    public func download(bucketName: String, objectName: String, destinationURL: URL) {
        let record = TransferRecord(
            direction: .download,
            displayName: URL(fileURLWithPath: objectName).lastPathComponent,
            sourcePath: "\(bucketName)/\(objectName)",
            destinationPath: destinationURL.path
        )
        enqueue(record, replay: .download(bucketName: bucketName, objectName: objectName, destinationURL: destinationURL))
    }

    public func cancel(recordID: UUID) {
        if let task = tasks[recordID] {
            cancelledRecordIDs.insert(recordID)
            tasks[recordID] = nil
            update(
                recordID: recordID,
                status: .cancelled,
                progress: currentProgress(for: recordID),
                errorMessage: AppError.cancelled.localizedDescription
            )
            task.cancel()
            processQueueIfNeeded()
            return
        }
        cancelledRecordIDs.insert(recordID)
        update(recordID: recordID, status: .cancelled, progress: currentProgress(for: recordID), errorMessage: AppError.cancelled.localizedDescription)
        processQueueIfNeeded()
    }

    public func retry(recordID: UUID) {
        guard replayDescriptors[recordID] != nil else { return }
        cancelledRecordIDs.remove(recordID)
        update(recordID: recordID, status: .queued, progress: 0, errorMessage: nil)
        processQueueIfNeeded()
    }

    public func clearCompleted() {
        records.removeAll { [.completed, .cancelled].contains($0.status) }
    }

    private func enqueue(_ record: TransferRecord, replay: TransferReplayDescriptor) {
        records.insert(record, at: 0)
        replayDescriptors[record.id] = replay
        update(recordID: record.id, status: .queued, progress: 0, errorMessage: nil)
        processQueueIfNeeded()
    }

    private func processQueueIfNeeded() {
        while tasks.count < maxConcurrentTransfers,
              let nextRecord = nextQueuedRecord(),
              let replay = replayDescriptors[nextRecord.id] {
            start(recordID: nextRecord.id, replay: replay, auth: auth)
        }
    }

    private func nextQueuedRecord() -> TransferRecord? {
        records.reversed().first(where: { $0.status == .queued })
    }

    private func start(recordID: UUID, replay: TransferReplayDescriptor, auth: OCIAuthenticationConfig) {
        cancelledRecordIDs.remove(recordID)
        update(recordID: recordID, status: .running, progress: 0, errorMessage: nil)
        tasks[recordID] = Task {
            await self.execute(recordID: recordID, replay: replay, auth: auth)
        }
    }

    private func execute(recordID: UUID, replay: TransferReplayDescriptor, auth: OCIAuthenticationConfig) async {
        do {
            switch replay {
            case let .upload(fileURL, bucketName, objectName, contentType):
                try await service.uploadObject(
                    bucketName: bucketName,
                    objectName: objectName,
                    fileURL: fileURL,
                    contentType: contentType,
                    using: auth
                ) { progress in
                    Task { @MainActor in
                        self.update(recordID: recordID, status: .running, progress: progress)
                    }
                }
            case let .download(bucketName, objectName, destinationURL):
                try await service.downloadObject(
                    bucketName: bucketName,
                    objectName: objectName,
                    destinationURL: destinationURL,
                    using: auth
                ) { progress in
                    Task { @MainActor in
                        self.update(recordID: recordID, status: .running, progress: progress)
                    }
                }
            }

            if cancelledRecordIDs.contains(recordID) || Task.isCancelled {
                update(
                    recordID: recordID,
                    status: .cancelled,
                    progress: currentProgress(for: recordID),
                    errorMessage: AppError.cancelled.localizedDescription
                )
                cancelledRecordIDs.remove(recordID)
                processQueueIfNeeded()
                return
            }

            update(recordID: recordID, status: .completed, progress: 1, errorMessage: nil)
        } catch {
            let appError = AppError.from(error)
            if cancelledRecordIDs.contains(recordID) || appError == .cancelled || Task.isCancelled {
                update(
                    recordID: recordID,
                    status: .cancelled,
                    progress: currentProgress(for: recordID),
                    errorMessage: AppError.cancelled.localizedDescription
                )
                cancelledRecordIDs.remove(recordID)
                processQueueIfNeeded()
                return
            }
            let message = friendlyTransferMessage(for: appError, replay: replay)
            let logMetadata = transferLogMetadata(for: replay, error: appError.localizedDescription)
            logger.log(.error, category: "Transfer", message: transferLogMessage(for: replay), metadata: logMetadata)
            update(
                recordID: recordID,
                status: appError == .cancelled ? .cancelled : .failed,
                progress: currentProgress(for: recordID),
                errorMessage: message
            )
        }
        processQueueIfNeeded()
    }

    private func update(recordID: UUID, status: TransferStatus, progress: Double, errorMessage: String? = nil) {
        guard let index = records.firstIndex(where: { $0.id == recordID }) else { return }
        var record = records[index]
        record.status = status
        record.progress = progress
        record.errorMessage = errorMessage
        records[index] = record
        if status != .running {
            tasks[recordID] = nil
        }
    }

    private func currentProgress(for recordID: UUID) -> Double {
        records.first(where: { $0.id == recordID })?.progress ?? 0
    }

    private func transferLogMessage(for replay: TransferReplayDescriptor) -> String {
        switch replay {
        case .upload:
            return L10n.string("transfer.log.upload_failed")
        case .download:
            return L10n.string("transfer.log.download_failed")
        }
    }

    private func transferLogMetadata(for replay: TransferReplayDescriptor, error: String) -> [String: String] {
        switch replay {
        case let .upload(fileURL, _, objectName, _):
            return ["file": fileURL.lastPathComponent, "object": objectName, "error": error]
        case let .download(_, objectName, destinationURL):
            return ["object": objectName, "destination": destinationURL.path, "error": error]
        }
    }

    private func friendlyTransferMessage(for error: AppError, replay: TransferReplayDescriptor) -> String {
        switch error {
        case .cancelled:
            return AppError.cancelled.localizedDescription
        case .authentication:
            switch replay {
            case .upload:
                return L10n.string("transfer.error.auth.upload")
            case .download:
                return L10n.string("transfer.error.auth.download")
            }
        case .network:
            switch replay {
            case .upload:
                return L10n.string("transfer.error.network.upload")
            case .download:
                return L10n.string("transfer.error.network.download")
            }
        default:
            switch replay {
            case .upload:
                return L10n.string("transfer.error.generic.upload")
            case .download:
                return L10n.string("transfer.error.generic.download")
            }
        }
    }
}
