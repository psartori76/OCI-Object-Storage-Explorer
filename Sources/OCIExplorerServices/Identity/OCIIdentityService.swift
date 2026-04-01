import Foundation
import OCIExplorerCore

public final class OCIIdentityService: OCIIdentityServiceProtocol, @unchecked Sendable {
    private let signer: OCIRequestSignerProtocol
    private let httpClient: OCIHTTPClientProtocol
    private let logger: AppLogger
    private let decoder: JSONDecoder
    private let cache = RegionCache()

    public init(
        signer: OCIRequestSignerProtocol,
        httpClient: OCIHTTPClientProtocol,
        logger: AppLogger
    ) {
        self.signer = signer
        self.httpClient = httpClient
        self.logger = logger
        self.decoder = JSONDecoder()
    }

    public func listSubscribedRegions(using auth: OCIAuthenticationConfig) async throws -> [OCIRegion] {
        if let cached = await cache.value(for: auth.tenancyOCID) {
            return cached
        }

        let candidateRegions = Array(NSOrderedSet(array: [
            auth.region,
            "sa-saopaulo-1",
            "us-ashburn-1",
            "us-phoenix-1"
        ])) as? [String] ?? [auth.region]

        var lastError: Error?
        for region in candidateRegions where !region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            do {
                var request = URLRequest(url: try OCIEndpointBuilder.regionSubscriptionsURL(region: region, tenancyID: auth.tenancyOCID))
                request.httpMethod = "GET"
                let signed = try signer.sign(request, bodyData: nil, auth: auth)
                let (data, _) = try await httpClient.send(signed)
                let response = try decoder.decode([RegionSubscriptionDTO].self, from: data)
                let subscribed = response
                    .filter { $0.status.uppercased() == "READY" }
                    .map {
                        OCIRegion(
                            regionCode: $0.regionName,
                            regionKey: $0.regionKey,
                            regionName: $0.regionName,
                            status: $0.status,
                            isHomeRegion: $0.isHomeRegion
                        )
                    }
                    .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

                await cache.store(subscribed, for: auth.tenancyOCID)
                return subscribed
            } catch {
                lastError = error
                await logger.log(
                    .warning,
                    category: "Identity",
                    message: L10n.string("service.identity.lookup_failed"),
                    metadata: ["region": region, "error": AppError.from(error).localizedDescription]
                )
            }
        }

        throw lastError ?? AppError.network(L10n.string("service.identity.load_failed"))
    }
}

private struct RegionSubscriptionDTO: Codable {
    let regionKey: String
    let regionName: String
    let status: String
    let isHomeRegion: Bool
}

private actor RegionCache {
    private var values: [String: [OCIRegion]] = [:]

    func value(for tenancyID: String) -> [OCIRegion]? {
        values[tenancyID]
    }

    func store(_ regions: [OCIRegion], for tenancyID: String) {
        values[tenancyID] = regions
    }
}
