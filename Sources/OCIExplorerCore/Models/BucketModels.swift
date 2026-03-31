import Foundation

public enum BucketStorageTier: String, Codable, CaseIterable, Identifiable, Sendable {
    case standard = "Standard"
    case archive = "Archive"
    case infrequentAccess = "InfrequentAccess"

    public var id: String { rawValue }
}

public struct BucketSummary: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let namespace: String
    public let compartmentID: String?
    public let createdAt: Date?
    public let etag: String?
    public let publicAccessType: String?
    public let storageTier: String?

    public init(
        id: String,
        name: String,
        namespace: String,
        compartmentID: String?,
        createdAt: Date?,
        etag: String? = nil,
        publicAccessType: String? = nil,
        storageTier: String? = nil
    ) {
        self.id = id
        self.name = name
        self.namespace = namespace
        self.compartmentID = compartmentID
        self.createdAt = createdAt
        self.etag = etag
        self.publicAccessType = publicAccessType
        self.storageTier = storageTier
    }
}

public struct BucketDetails: Codable, Hashable, Sendable {
    public let name: String
    public let namespace: String
    public let compartmentID: String?
    public let createdAt: Date?
    public let storageTier: String?
    public let versioning: String?
    public let publicAccessType: String?
    public let autoTiering: String?

    public init(
        name: String,
        namespace: String,
        compartmentID: String?,
        createdAt: Date?,
        storageTier: String?,
        versioning: String?,
        publicAccessType: String?,
        autoTiering: String?
    ) {
        self.name = name
        self.namespace = namespace
        self.compartmentID = compartmentID
        self.createdAt = createdAt
        self.storageTier = storageTier
        self.versioning = versioning
        self.publicAccessType = publicAccessType
        self.autoTiering = autoTiering
    }
}

public struct CreateBucketRequestModel: Equatable, Sendable {
    public var name: String
    public var compartmentID: String
    public var storageTier: BucketStorageTier
    public var publicAccessType: String

    public init(
        name: String = "",
        compartmentID: String = "",
        storageTier: BucketStorageTier = .standard,
        publicAccessType: String = "NoPublicAccess"
    ) {
        self.name = name
        self.compartmentID = compartmentID
        self.storageTier = storageTier
        self.publicAccessType = publicAccessType
    }
}
