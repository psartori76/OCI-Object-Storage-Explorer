import Foundation
import OCIExplorerCore

public protocol ProfileStoreProtocol: Sendable {
    func loadProfiles() throws -> [AuthProfile]
    func saveProfiles(_ profiles: [AuthProfile]) throws
    func upsert(_ profile: AuthProfile) throws
    func deleteProfile(id: UUID) throws
}

public final class ProfileStore: ProfileStoreProtocol, @unchecked Sendable {
    private let fileManager: FileManager
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileManager: FileManager = .default, baseDirectory: URL? = nil) {
        self.fileManager = fileManager
        let baseDir = baseDirectory ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.fileURL = baseDir
            .appendingPathComponent("OCIObjectStorageExplorer", isDirectory: true)
            .appendingPathComponent("profiles.json")

        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public func loadProfiles() throws -> [AuthProfile] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([AuthProfile].self, from: data)
    }

    public func saveProfiles(_ profiles: [AuthProfile]) throws {
        try ensureDirectory()
        let data = try encoder.encode(profiles.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
        try data.write(to: fileURL, options: .atomic)
    }

    public func upsert(_ profile: AuthProfile) throws {
        var profiles = try loadProfiles()
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
        try saveProfiles(profiles)
    }

    public func deleteProfile(id: UUID) throws {
        let profiles = try loadProfiles().filter { $0.id != id }
        try saveProfiles(profiles)
    }

    private func ensureDirectory() throws {
        let directory = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}
