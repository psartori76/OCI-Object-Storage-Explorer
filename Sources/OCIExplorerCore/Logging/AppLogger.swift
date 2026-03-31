import Combine
import Foundation

public enum LogLevel: String, Codable, CaseIterable, Sendable {
    case debug
    case info
    case warning
    case error
}

public struct DiagnosticEntry: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let level: LogLevel
    public let category: String
    public let message: String
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        level: LogLevel,
        category: String,
        message: String,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.metadata = metadata
    }
}

@MainActor
public final class AppLogger: ObservableObject {
    @Published public private(set) var entries: [DiagnosticEntry]
    private let maxEntries: Int

    public init(maxEntries: Int = 200) {
        self.maxEntries = maxEntries
        self.entries = []
    }

    public func log(
        _ level: LogLevel,
        category: String,
        message: String,
        metadata: [String: String] = [:]
    ) {
        let entry = DiagnosticEntry(
            level: level,
            category: category,
            message: sanitize(message),
            metadata: metadata.mapValues(sanitize)
        )
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
    }

    public func clear() {
        entries.removeAll()
    }

    private func sanitize(_ value: String) -> String {
        let lowered = value.lowercased()
        let sensitiveHints = ["private", "secret", "token", "passphrase", "authorization"]
        if sensitiveHints.contains(where: lowered.contains) {
            return "[REDACTED]"
        }
        return value
    }
}
