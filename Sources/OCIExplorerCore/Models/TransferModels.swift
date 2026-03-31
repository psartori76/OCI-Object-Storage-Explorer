import Foundation

public enum TransferDirection: String, Codable, Sendable {
    case upload
    case download
}

public enum TransferStatus: String, Codable, Sendable {
    case queued
    case running
    case completed
    case failed
    case cancelled

    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled:
            return true
        case .queued, .running:
            return false
        }
    }
}

public struct TransferRecord: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let direction: TransferDirection
    public let displayName: String
    public let sourcePath: String
    public let destinationPath: String
    public var progress: Double
    public var status: TransferStatus
    public var errorMessage: String?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        direction: TransferDirection,
        displayName: String,
        sourcePath: String,
        destinationPath: String,
        progress: Double = 0,
        status: TransferStatus = .queued,
        errorMessage: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.direction = direction
        self.displayName = displayName
        self.sourcePath = sourcePath
        self.destinationPath = destinationPath
        self.progress = progress
        self.status = status
        self.errorMessage = errorMessage
        self.createdAt = createdAt
    }
}
