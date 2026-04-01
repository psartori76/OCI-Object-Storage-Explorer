import Foundation

public enum LocalizedDisplayValue {
    public static func fileKind(isFolder: Bool) -> String {
        L10n.string(isFolder ? "common.folder" : "common.file")
    }

    public static func bucketStorageTier(_ tier: BucketStorageTier) -> String {
        switch tier {
        case .standard:
            return L10n.string("bucket.storage_tier.standard")
        case .archive:
            return L10n.string("bucket.storage_tier.archive")
        case .infrequentAccess:
            return L10n.string("bucket.storage_tier.infrequent_access")
        }
    }

    public static func bucketStorageTier(rawValue: String?) -> String {
        guard let rawValue, !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return L10n.string("common.not_available")
        }

        switch rawValue {
        case BucketStorageTier.standard.rawValue:
            return bucketStorageTier(.standard)
        case BucketStorageTier.archive.rawValue:
            return bucketStorageTier(.archive)
        case BucketStorageTier.infrequentAccess.rawValue:
            return bucketStorageTier(.infrequentAccess)
        default:
            return rawValue
        }
    }

    public static func publicAccess(_ rawValue: String?) -> String {
        guard let rawValue, !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return L10n.string("common.not_available")
        }

        switch rawValue {
        case "NoPublicAccess":
            return L10n.string("bucket.public_access.none")
        case "ObjectRead":
            return L10n.string("bucket.public_access.object_read")
        default:
            return rawValue
        }
    }

    public static func versioning(_ rawValue: String?) -> String {
        guard let rawValue, !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return L10n.string("common.not_available")
        }

        let normalized = rawValue.lowercased()
        if normalized.contains("enabled") {
            return L10n.string("common.enabled")
        }
        if normalized.contains("disabled") {
            return L10n.string("common.disabled")
        }
        return rawValue
    }

    public static func yesNo(_ value: Bool, falseUsesDash: Bool = false) -> String {
        if value {
            return L10n.string("common.yes")
        }
        return falseUsesDash ? L10n.string("common.not_available") : L10n.string("common.no")
    }
}
