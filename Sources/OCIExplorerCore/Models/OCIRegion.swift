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
        let friendly = Self.friendlyRegionNames[regionCode] ?? regionCode
        return "\(friendly) — \(regionCode)"
    }

    private static let friendlyRegionNames: [String: String] = [
        "us-ashburn-1": "US East (Ashburn)",
        "us-phoenix-1": "US West (Phoenix)",
        "sa-saopaulo-1": "Brazil East (São Paulo)",
        "sa-vinhedo-1": "Brazil Southeast (Vinhedo)",
        "sa-santiago-1": "Chile Central (Santiago)",
        "sa-valparaiso-1": "Chile Northwest (Valparaíso)",
        "mx-queretaro-1": "Mexico Central (Querétaro)",
        "mx-monterrey-1": "Mexico Northeast (Monterrey)",
        "uk-london-1": "UK South (London)",
        "uk-cardiff-1": "UK West (Cardiff)",
        "eu-frankfurt-1": "Germany Central (Frankfurt)",
        "eu-amsterdam-1": "Netherlands Northwest (Amsterdam)",
        "eu-madrid-1": "Spain Central (Madrid)",
        "eu-jovanovac-1": "Serbia South (Jovanovac)",
        "eu-marseille-1": "France South (Marseille)",
        "eu-milan-1": "Italy Northwest (Milan)",
        "eu-paris-1": "France Central (Paris)",
        "eu-stockholm-1": "Sweden Central (Stockholm)",
        "eu-zurich-1": "Switzerland North (Zurich)",
        "ca-toronto-1": "Canada Southeast (Toronto)",
        "ca-montreal-1": "Canada Northeast (Montreal)",
        "me-abudhabi-1": "UAE East (Abu Dhabi)",
        "me-dubai-1": "UAE Central (Dubai)",
        "me-jeddah-1": "Saudi Arabia West (Jeddah)",
        "me-jerusalem-1": "Israel Central (Jerusalem)",
        "me-dcc-muscat-1": "Oman Dedicated Region (Muscat)",
        "af-johannesburg-1": "South Africa Central (Johannesburg)",
        "ap-chuncheon-1": "South Korea North (Chuncheon)",
        "ap-hyderabad-1": "India South (Hyderabad)",
        "ap-melbourne-1": "Australia Southeast (Melbourne)",
        "ap-tokyo-1": "Japan East (Tokyo)",
        "ap-osaka-1": "Japan Central (Osaka)",
        "ap-chiyoda-1": "Japan Central (Chiyoda)",
        "ap-mumbai-1": "India West (Mumbai)",
        "ap-seoul-1": "South Korea Central (Seoul)",
        "ap-singapore-1": "Singapore West (Singapore)",
        "ap-singapore-2": "Singapore Central (Singapore)",
        "ap-sydney-1": "Australia East (Sydney)",
        "il-jerusalem-1": "Israel Central (Jerusalem)",
        "us-sanjose-1": "US West (San Jose)",
        "us-saltlake-2": "US West (Salt Lake City)",
        "us-langley-1": "US Gov East (Langley)",
        "us-luke-1": "US Gov West (Luke)",
        "us-gov-ashburn-1": "US Gov East (Ashburn)",
        "us-gov-phoenix-1": "US Gov Southwest (Phoenix)",
        "us-gov-chicago-1": "US Gov Midwest (Chicago)",
        "uk-gov-london-1": "UK Gov South (London)",
        "ap-dcc-canberra-1": "Australia Dedicated Region (Canberra)",
        "ap-dcc-gazipur-1": "Bangladesh Dedicated Region (Gazipur)",
        "ap-dcc-mysore-1": "India Dedicated Region (Mysore)",
        "eu-dcc-milan-1": "Italy Dedicated Region (Milan 1)",
        "eu-dcc-milan-2": "Italy Dedicated Region (Milan 2)"
    ]
}
