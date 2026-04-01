import Foundation

public struct OCIRegion: Identifiable, Codable, Hashable, Sendable {
    public let regionCode: String
    public let regionKey: String
    public let regionName: String
    public let status: String
    public let isHomeRegion: Bool

    public init(
        regionCode: String,
        regionKey: String,
        regionName: String,
        status: String,
        isHomeRegion: Bool
    ) {
        self.regionCode = regionCode
        self.regionKey = regionKey
        self.regionName = regionName
        self.status = status
        self.isHomeRegion = isHomeRegion
    }

    public var id: String { regionCode }

    public var displayName: String {
        let key = "region.\(regionCode)"
        let localized = L10n.string(key)
        let fallbackName = regionName == regionCode ? regionCode : regionName
        let friendly = localized == key ? fallbackName : localized
        return "\(friendly) — \(regionCode)"
    }
}
