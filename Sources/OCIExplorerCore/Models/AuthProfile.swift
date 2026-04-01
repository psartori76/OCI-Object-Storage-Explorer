import Foundation

public enum AuthenticationMethod: String, Codable, CaseIterable, Identifiable, Sendable {
    case apiKey
    case sessionToken
    case instancePrincipal
    case resourcePrincipal
    case ociCLIConfig

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .apiKey:
            return L10n.string("auth.method.api_key")
        case .sessionToken:
            return L10n.string("auth.method.session_token")
        case .instancePrincipal:
            return L10n.string("auth.method.instance_principal")
        case .resourcePrincipal:
            return L10n.string("auth.method.resource_principal")
        case .ociCLIConfig:
            return L10n.string("auth.method.oci_cli_config")
        }
    }
}

public struct AuthProfile: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var method: AuthenticationMethod
    public var tenancyOCID: String
    public var userOCID: String
    public var fingerprint: String
    public var region: String
    public var namespace: String?
    public var defaultCompartmentOCID: String?
    public var privateKeyPathHint: String?
    public var rememberMe: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        method: AuthenticationMethod = .apiKey,
        tenancyOCID: String,
        userOCID: String,
        fingerprint: String,
        region: String,
        namespace: String? = nil,
        defaultCompartmentOCID: String? = nil,
        privateKeyPathHint: String? = nil,
        rememberMe: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.method = method
        self.tenancyOCID = tenancyOCID
        self.userOCID = userOCID
        self.fingerprint = fingerprint
        self.region = region
        self.namespace = namespace
        self.defaultCompartmentOCID = defaultCompartmentOCID
        self.privateKeyPathHint = privateKeyPathHint
        self.rememberMe = rememberMe
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct AuthProfileSecrets: Equatable, Sendable {
    public var privateKeyPEM: String
    public var passphrase: String?

    public init(privateKeyPEM: String, passphrase: String? = nil) {
        self.privateKeyPEM = privateKeyPEM
        self.passphrase = passphrase
    }
}

public struct OCIAuthenticationConfig: Equatable, Sendable {
    public var tenancyOCID: String
    public var userOCID: String
    public var fingerprint: String
    public var region: String
    public var namespace: String?
    public var compartmentOCID: String
    public var privateKeyPEM: String
    public var passphrase: String?

    public init(
        tenancyOCID: String,
        userOCID: String,
        fingerprint: String,
        region: String,
        namespace: String? = nil,
        compartmentOCID: String,
        privateKeyPEM: String,
        passphrase: String? = nil
    ) {
        self.tenancyOCID = tenancyOCID
        self.userOCID = userOCID
        self.fingerprint = fingerprint
        self.region = region
        self.namespace = namespace
        self.compartmentOCID = compartmentOCID
        self.privateKeyPEM = privateKeyPEM
        self.passphrase = passphrase
    }

    public var keyID: String {
        "\(tenancyOCID)/\(userOCID)/\(fingerprint)"
    }

    public var objectStorageHost: String {
        "objectstorage.\(region).oraclecloud.com"
    }
}

public struct ConnectionTestResult: Equatable, Sendable {
    public let resolvedNamespace: String
    public let region: String
    public let message: String

    public init(resolvedNamespace: String, region: String, message: String) {
        self.resolvedNamespace = resolvedNamespace
        self.region = region
        self.message = message
    }
}
