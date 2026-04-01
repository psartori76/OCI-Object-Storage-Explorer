import Foundation
import OCIExplorerCore
import Security

public protocol KeychainServiceProtocol: Sendable {
    func storeSecrets(_ secrets: AuthProfileSecrets, for profileID: UUID) throws
    func loadSecrets(for profileID: UUID) throws -> AuthProfileSecrets?
    func deleteSecrets(for profileID: UUID) throws
    func duplicateSecrets(from sourceProfileID: UUID, to destinationProfileID: UUID) throws
}

public final class KeychainService: KeychainServiceProtocol, @unchecked Sendable {
    private let serviceName = "com.paulosartori.oci-object-storage-explorer"

    public init() {}

    public func storeSecrets(_ secrets: AuthProfileSecrets, for profileID: UUID) throws {
        try store(secret: secrets.privateKeyPEM.data(using: .utf8) ?? Data(), account: keyAccount(for: profileID, suffix: "privateKey"))
        try store(secret: Data((secrets.passphrase ?? "").utf8), account: keyAccount(for: profileID, suffix: "passphrase"))
    }

    public func loadSecrets(for profileID: UUID) throws -> AuthProfileSecrets? {
        guard let privateKeyData = try loadSecret(account: keyAccount(for: profileID, suffix: "privateKey")) else {
            return nil
        }

        let passphraseData = try loadSecret(account: keyAccount(for: profileID, suffix: "passphrase"))
        let passphrase = passphraseData.flatMap { String(data: $0, encoding: .utf8) }.flatMap { $0.isEmpty ? nil : $0 }
        guard let privateKeyPEM = String(data: privateKeyData, encoding: .utf8) else {
            throw AppError.configuration(L10n.string("error.keychain.decode_private_key"))
        }
        return AuthProfileSecrets(privateKeyPEM: privateKeyPEM, passphrase: passphrase)
    }

    public func deleteSecrets(for profileID: UUID) throws {
        try deleteSecret(account: keyAccount(for: profileID, suffix: "privateKey"))
        try deleteSecret(account: keyAccount(for: profileID, suffix: "passphrase"))
    }

    public func duplicateSecrets(from sourceProfileID: UUID, to destinationProfileID: UUID) throws {
        if let secrets = try loadSecrets(for: sourceProfileID) {
            try storeSecrets(secrets, for: destinationProfileID)
        }
    }

    private func keyAccount(for profileID: UUID, suffix: String) -> String {
        "\(profileID.uuidString).\(suffix)"
    }

    private func store(secret: Data, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = secret
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AppError.configuration(L10n.string("error.keychain.save", status))
        }
    }

    private func loadSecret(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw AppError.configuration(L10n.string("error.keychain.read", status))
        }
        return item as? Data
    }

    private func deleteSecret(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess, status != errSecItemNotFound {
            throw AppError.configuration(L10n.string("error.keychain.delete", status))
        }
    }
}
