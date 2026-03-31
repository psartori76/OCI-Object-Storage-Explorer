import Foundation
import OCIExplorerCore

public protocol PARHistoryStoreProtocol: Sendable {
    func loadHistory() throws -> [PARSummary]
    func save(_ history: [PARSummary]) throws
    func upsert(_ item: PARSummary) throws
    func remove(id: String) throws
}

public final class PARHistoryStore: PARHistoryStoreProtocol, @unchecked Sendable {
    private let fileManager: FileManager
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileManager: FileManager = .default, baseDirectory: URL? = nil) {
        self.fileManager = fileManager
        let baseDir = baseDirectory ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.fileURL = baseDir
            .appendingPathComponent("OCIObjectStorageExplorer", isDirectory: true)
            .appendingPathComponent("par-history.json")
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public func loadHistory() throws -> [PARSummary] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([PARSummary].self, from: data)
    }

    public func save(_ history: [PARSummary]) throws {
        try ensureDirectory()
        let data = try encoder.encode(history.sorted { ($0.timeCreated ?? .distantPast) > ($1.timeCreated ?? .distantPast) })
        try data.write(to: fileURL, options: .atomic)
    }

    public func upsert(_ item: PARSummary) throws {
        var history = try loadHistory()
        if let index = history.firstIndex(where: { $0.id == item.id }) {
            history[index] = item
        } else {
            history.append(item)
        }
        try save(history)
    }

    public func remove(id: String) throws {
        let history = try loadHistory().filter { $0.id != id }
        try save(history)
    }

    private func ensureDirectory() throws {
        let directory = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}
