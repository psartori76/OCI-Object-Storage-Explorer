import Foundation
import OCIExplorerCore

public protocol OCIIdentityServiceProtocol: Sendable {
    func listSubscribedRegions(using auth: OCIAuthenticationConfig) async throws -> [OCIRegion]
}
