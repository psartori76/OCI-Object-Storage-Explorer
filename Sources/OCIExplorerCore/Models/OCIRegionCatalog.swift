import Foundation

public enum OCIRegionCatalog {
    public static let fallbackRegionCode = "us-ashburn-1"

    public static let allRegions: [OCIRegion] = [
        region("sa-saopaulo-1", key: "GRU"),
        region("us-ashburn-1", key: "IAD", isHomeRegion: true),
        region("us-phoenix-1", key: "PHX"),
        region("ca-montreal-1", key: "YUL"),
        region("ca-toronto-1", key: "YYZ"),
        region("sa-santiago-1", key: "SCL"),
        region("sa-valparaiso-1", key: "VAP"),
        region("mx-queretaro-1", key: "QRO"),
        region("mx-monterrey-1", key: "MTY"),
        region("uk-london-1", key: "LHR"),
        region("uk-cardiff-1", key: "CWL"),
        region("eu-frankfurt-1", key: "FRA"),
        region("eu-amsterdam-1", key: "AMS"),
        region("eu-madrid-1", key: "MAD"),
        region("eu-jovanovac-1", key: "BEG"),
        region("eu-marseille-1", key: "MRS"),
        region("eu-milan-1", key: "MXP"),
        region("eu-paris-1", key: "CDG"),
        region("eu-stockholm-1", key: "ARN"),
        region("eu-zurich-1", key: "ZRH"),
        region("me-abudhabi-1", key: "AUH"),
        region("me-dubai-1", key: "DXB"),
        region("me-jeddah-1", key: "JED"),
        region("me-jerusalem-1", key: "JRS"),
        region("af-johannesburg-1", key: "JNB"),
        region("ap-chuncheon-1", key: "YNY"),
        region("ap-hyderabad-1", key: "HYD"),
        region("ap-melbourne-1", key: "MEL"),
        region("ap-mumbai-1", key: "BOM"),
        region("ap-osaka-1", key: "KIX"),
        region("ap-seoul-1", key: "ICN"),
        region("ap-singapore-1", key: "SIN"),
        region("ap-sydney-1", key: "SYD"),
        region("ap-tokyo-1", key: "NRT"),
        region("ap-chiyoda-1", key: "TYO"),
        region("ap-singapore-2", key: "XSP"),
        region("il-jerusalem-1", key: "JRS"),
        region("sa-vinhedo-1", key: "VCP"),
        region("us-sanjose-1", key: "SJC"),
        region("us-saltlake-2", key: "SLC"),
        region("us-luke-1", key: "LUK"),
        region("us-langley-1", key: "LFI"),
        region("us-gov-ashburn-1", key: "GOVIAD"),
        region("us-gov-phoenix-1", key: "GOVPHX"),
        region("us-gov-chicago-1", key: "GOVORD"),
        region("uk-gov-london-1", key: "GOVLHR"),
        region("ap-dcc-canberra-1", key: "CBR"),
        region("ap-dcc-gazipur-1", key: "DAC"),
        region("ap-dcc-mysore-1", key: "MYQ"),
        region("eu-dcc-milan-1", key: "MIL"),
        region("eu-dcc-milan-2", key: "ML2"),
        region("me-dcc-muscat-1", key: "MCT")
    ].sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

    public static func region(for regionCode: String) -> OCIRegion? {
        allRegions.first { $0.regionCode == regionCode }
    }

    private static func region(_ code: String, key: String, isHomeRegion: Bool = false) -> OCIRegion {
        OCIRegion(
            regionCode: code,
            regionKey: key,
            regionName: code,
            status: "READY",
            isHomeRegion: isHomeRegion
        )
    }
}
