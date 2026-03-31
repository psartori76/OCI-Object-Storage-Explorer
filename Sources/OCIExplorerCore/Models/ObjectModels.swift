import Foundation

public enum BrowserLayoutMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case tree
    case list

    public var id: String { rawValue }
}

public struct ObjectBrowserItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let fullPath: String
    public let isFolder: Bool
    public let size: Int64?
    public let contentType: String?
    public let modifiedAt: Date?
    public let etag: String?
    public let storageTier: String?

    public init(
        id: String? = nil,
        name: String,
        fullPath: String,
        isFolder: Bool,
        size: Int64? = nil,
        contentType: String? = nil,
        modifiedAt: Date? = nil,
        etag: String? = nil,
        storageTier: String? = nil
    ) {
        self.id = id ?? fullPath
        self.name = name
        self.fullPath = fullPath
        self.isFolder = isFolder
        self.size = size
        self.contentType = contentType
        self.modifiedAt = modifiedAt
        self.etag = etag
        self.storageTier = storageTier
    }
}

public struct ObjectMetadata: Codable, Hashable, Sendable {
    public let name: String
    public let size: Int64?
    public let contentType: String?
    public let modifiedAt: Date?
    public let etag: String?
    public let storageTier: String?
    public let additionalHeaders: [String: String]

    public init(
        name: String,
        size: Int64?,
        contentType: String?,
        modifiedAt: Date?,
        etag: String?,
        storageTier: String?,
        additionalHeaders: [String: String] = [:]
    ) {
        self.name = name
        self.size = size
        self.contentType = contentType
        self.modifiedAt = modifiedAt
        self.etag = etag
        self.storageTier = storageTier
        self.additionalHeaders = additionalHeaders
    }
}

public struct ObjectVersionSummary: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let versionID: String
    public let size: Int64?
    public let modifiedAt: Date?
    public let timeCreated: Date?
    public let etag: String?
    public let storageTier: String?
    public let isDeleteMarker: Bool
    public let isCurrent: Bool

    public init(
        id: String? = nil,
        name: String,
        versionID: String,
        size: Int64?,
        modifiedAt: Date?,
        timeCreated: Date?,
        etag: String?,
        storageTier: String?,
        isDeleteMarker: Bool,
        isCurrent: Bool
    ) {
        self.id = id ?? "\(name)#\(versionID)"
        self.name = name
        self.versionID = versionID
        self.size = size
        self.modifiedAt = modifiedAt
        self.timeCreated = timeCreated
        self.etag = etag
        self.storageTier = storageTier
        self.isDeleteMarker = isDeleteMarker
        self.isCurrent = isCurrent
    }
}

public struct ObjectListingPage: Sendable {
    public let prefix: String
    public let items: [ObjectBrowserItem]
    public let nextStartWith: String?

    public init(prefix: String, items: [ObjectBrowserItem], nextStartWith: String?) {
        self.prefix = prefix
        self.items = items
        self.nextStartWith = nextStartWith
    }
}
