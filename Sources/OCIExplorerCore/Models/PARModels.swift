import Foundation

public enum PARAccessType: String, Codable, CaseIterable, Identifiable, Sendable {
    case objectRead = "ObjectRead"
    case objectWrite = "ObjectWrite"
    case objectReadWrite = "ObjectReadWrite"
    case anyObjectRead = "AnyObjectRead"
    case anyObjectWrite = "AnyObjectWrite"
    case anyObjectReadWrite = "AnyObjectReadWrite"

    public var id: String { rawValue }

    public var isObjectScoped: Bool {
        switch self {
        case .objectRead, .objectWrite, .objectReadWrite:
            true
        case .anyObjectRead, .anyObjectWrite, .anyObjectReadWrite:
            false
        }
    }
}

public struct PARSummary: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let accessType: String
    public let timeCreated: Date?
    public let timeExpires: Date?
    public let objectName: String?
    public let accessURI: String
    public let fullPath: String?
    public let bucketName: String?
    public let namespace: String?

    public init(
        id: String,
        name: String,
        accessType: String,
        timeCreated: Date?,
        timeExpires: Date?,
        objectName: String?,
        accessURI: String,
        fullPath: String?,
        bucketName: String? = nil,
        namespace: String? = nil
    ) {
        self.id = id
        self.name = name
        self.accessType = accessType
        self.timeCreated = timeCreated
        self.timeExpires = timeExpires
        self.objectName = objectName
        self.accessURI = accessURI
        self.fullPath = fullPath
        self.bucketName = bucketName
        self.namespace = namespace
    }
}

public struct CreatePARRequestModel: Equatable, Sendable {
    public var name: String
    public var accessType: PARAccessType
    public var expiresAt: Date
    public var objectName: String?
    public var bucketListingAction: String?

    public init(
        name: String = "",
        accessType: PARAccessType = .objectRead,
        expiresAt: Date = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now,
        objectName: String? = nil,
        bucketListingAction: String? = nil
    ) {
        self.name = name
        self.accessType = accessType
        self.expiresAt = expiresAt
        self.objectName = objectName
        self.bucketListingAction = bucketListingAction
    }
}
