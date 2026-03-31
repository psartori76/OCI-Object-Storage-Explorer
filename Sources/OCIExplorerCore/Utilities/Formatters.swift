import Foundation

public enum SharedFormatters {
    @MainActor
    public static let dateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    public static func parseISO8601(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? parseSimpleISO8601(value)
    }

    public static func parseSimpleISO8601(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    public static func formatISO8601WithFractional(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    public static func formatByteCount(_ count: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: count)
    }
}

public extension Optional where Wrapped == Date {
    @MainActor
    var friendlyDateText: String {
        switch self {
        case let .some(date):
            SharedFormatters.dateTime.string(from: date)
        case .none:
            "—"
        }
    }
}

public extension Optional where Wrapped == Int64 {
    var friendlyByteText: String {
        switch self {
        case let .some(value):
            SharedFormatters.formatByteCount(value)
        case .none:
            "—"
        }
    }
}
