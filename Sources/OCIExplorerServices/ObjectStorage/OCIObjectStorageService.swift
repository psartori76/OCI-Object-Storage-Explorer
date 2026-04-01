import Foundation
import OCIExplorerCore

public final class OCIObjectStorageService: OCIObjectStorageServiceProtocol, @unchecked Sendable {
    private let signer: OCIRequestSignerProtocol
    private let httpClient: OCIHTTPClientProtocol
    private let logger: AppLogger
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(
        signer: OCIRequestSignerProtocol,
        httpClient: OCIHTTPClientProtocol,
        logger: AppLogger
    ) {
        self.signer = signer
        self.httpClient = httpClient
        self.logger = logger
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = SharedFormatters.parseISO8601(value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: L10n.string("error.decoding.invalid_date", value))
        }
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    public func testConnection(using auth: OCIAuthenticationConfig) async throws -> ConnectionTestResult {
        let namespace = try await resolveNamespace(using: auth)
        await logger.log(.info, category: "Auth", message: L10n.string("service.connection.validated"), metadata: ["namespace": namespace])
        return ConnectionTestResult(
            resolvedNamespace: namespace,
            region: auth.region,
            message: L10n.string("service.connection.success")
        )
    }

    public func listBuckets(using auth: OCIAuthenticationConfig) async throws -> [BucketSummary] {
        let namespace = try await resolveNamespace(using: auth)
        var request = URLRequest(url: try OCIEndpointBuilder.bucketsURL(region: auth.region, namespace: namespace, compartmentID: auth.compartmentOCID))
        request.httpMethod = "GET"
        let signed = try signer.sign(request, bodyData: nil, auth: auth)
        let (data, _) = try await httpClient.send(signed)
        let response = try decoder.decode([BucketDTO].self, from: data)
        return response.map {
            BucketSummary(
                id: $0.id ?? $0.name,
                name: $0.name,
                namespace: namespace,
                compartmentID: $0.compartmentID,
                createdAt: $0.timeCreated,
                etag: nil,
                publicAccessType: $0.publicAccessType,
                storageTier: $0.storageTier
            )
        }
    }

    public func createBucket(_ requestModel: CreateBucketRequestModel, using auth: OCIAuthenticationConfig) async throws -> BucketSummary {
        let namespace = try await resolveNamespace(using: auth)
        let payload = CreateBucketDTO(
            compartmentID: requestModel.compartmentID,
            name: requestModel.name,
            publicAccessType: requestModel.publicAccessType,
            storageTier: requestModel.storageTier.rawValue
        )
        let body = try encoder.encode(payload)
        var request = URLRequest(url: try OCIEndpointBuilder.bucketsURL(region: auth.region, namespace: namespace))
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        let signed = try signer.sign(request, bodyData: body, auth: auth)
        _ = try await httpClient.send(signed)
        return try await getBucketSummary(named: requestModel.name, namespace: namespace, auth: auth)
    }

    public func deleteBucket(named bucketName: String, using auth: OCIAuthenticationConfig) async throws {
        let namespace = try await resolveNamespace(using: auth)
        var request = URLRequest(url: try OCIEndpointBuilder.bucketURL(region: auth.region, namespace: namespace, bucketName: bucketName))
        request.httpMethod = "DELETE"
        let signed = try signer.sign(request, bodyData: nil, auth: auth)
        _ = try await httpClient.send(signed)
    }

    public func getBucketDetails(named bucketName: String, using auth: OCIAuthenticationConfig) async throws -> BucketDetails {
        let namespace = try await resolveNamespace(using: auth)
        var request = URLRequest(url: try OCIEndpointBuilder.bucketURL(region: auth.region, namespace: namespace, bucketName: bucketName))
        request.httpMethod = "GET"
        let signed = try signer.sign(request, bodyData: nil, auth: auth)
        let (data, _) = try await httpClient.send(signed)
        let bucket = try decoder.decode(BucketDetailsDTO.self, from: data)
        return BucketDetails(
            name: bucket.name,
            namespace: namespace,
            compartmentID: bucket.compartmentID,
            createdAt: bucket.timeCreated,
            storageTier: bucket.storageTier,
            versioning: bucket.versioning,
            publicAccessType: bucket.publicAccessType,
            autoTiering: bucket.autoTiering
        )
    }

    public func listObjects(bucketName: String, prefix: String, using auth: OCIAuthenticationConfig, start: String?) async throws -> ObjectListingPage {
        let namespace = try await resolveNamespace(using: auth)
        var request = URLRequest(url: try OCIEndpointBuilder.listObjectsURL(region: auth.region, namespace: namespace, bucketName: bucketName, prefix: prefix, start: start))
        request.httpMethod = "GET"
        let signed = try signer.sign(request, bodyData: nil, auth: auth)
        let (data, _) = try await httpClient.send(signed)
        let response = try decoder.decode(ListObjectsResponseDTO.self, from: data)

        let folderItems = response.prefixes.map { prefixPath -> ObjectBrowserItem in
            let trimmed = prefixPath.hasSuffix("/") ? String(prefixPath.dropLast()) : prefixPath
            let name = trimmed.split(separator: "/").last.map(String.init) ?? trimmed
            return ObjectBrowserItem(name: name, fullPath: prefixPath, isFolder: true)
        }

        let objectItems = response.objects.map { object in
            ObjectBrowserItem(
                name: object.name.split(separator: "/").last.map(String.init) ?? object.name,
                fullPath: object.name,
                isFolder: false,
                size: object.size,
                contentType: nil,
                modifiedAt: object.timeModified,
                etag: object.etag,
                storageTier: object.storageTier
            )
        }

        return ObjectListingPage(
            prefix: prefix,
            items: (folderItems + objectItems).sorted { lhs, rhs in
                if lhs.isFolder != rhs.isFolder {
                    return lhs.isFolder && !rhs.isFolder
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            },
            nextStartWith: response.nextStartWith
        )
    }

    public func listObjectVersions(bucketName: String, objectName: String, using auth: OCIAuthenticationConfig) async throws -> [ObjectVersionSummary] {
        let namespace = try await resolveNamespace(using: auth)
        var request = URLRequest(url: try OCIEndpointBuilder.objectVersionsURL(region: auth.region, namespace: namespace, bucketName: bucketName, objectName: objectName))
        request.httpMethod = "GET"
        let signed = try signer.sign(request, bodyData: nil, auth: auth)
        let (data, _) = try await httpClient.send(signed)
        let response = try decoder.decode(ListObjectVersionsResponseDTO.self, from: data)
        let matching = response.items.filter { $0.name == objectName }
        let sorted = matching.sorted {
            ($0.timeModified ?? $0.timeCreated ?? .distantPast) > ($1.timeModified ?? $1.timeCreated ?? .distantPast)
        }
        return sorted.enumerated().map { index, version in
            ObjectVersionSummary(
                name: version.name,
                versionID: version.versionID,
                size: version.size,
                modifiedAt: version.timeModified,
                timeCreated: version.timeCreated,
                etag: version.etag,
                storageTier: version.storageTier,
                isDeleteMarker: version.isDeleteMarker ?? false,
                isCurrent: index == 0
            )
        }
    }

    public func metadataForObject(bucketName: String, objectName: String, using auth: OCIAuthenticationConfig) async throws -> ObjectMetadata {
        let namespace = try await resolveNamespace(using: auth)
        var request = URLRequest(url: try OCIEndpointBuilder.objectURL(region: auth.region, namespace: namespace, bucketName: bucketName, objectName: objectName))
        request.httpMethod = "HEAD"
        let signed = try signer.sign(request, bodyData: nil, auth: auth)
        let (_, response) = try await httpClient.send(signed)
        let headers = response.allHeaderFields.reduce(into: [String: String]()) { partialResult, item in
            partialResult[String(describing: item.key)] = String(describing: item.value)
        }
        return ObjectMetadata(
            name: objectName,
            size: headers["Content-Length"].flatMap(Int64.init),
            contentType: headers["Content-Type"],
            modifiedAt: headers["Last-Modified"].flatMap(parseHTTPDate),
            etag: headers["Etag"],
            storageTier: headers["Storage-Tier"],
            additionalHeaders: headers
        )
    }

    public func deleteObject(bucketName: String, objectName: String, using auth: OCIAuthenticationConfig) async throws {
        let namespace = try await resolveNamespace(using: auth)
        var request = URLRequest(url: try OCIEndpointBuilder.objectURL(region: auth.region, namespace: namespace, bucketName: bucketName, objectName: objectName))
        request.httpMethod = "DELETE"
        let signed = try signer.sign(request, bodyData: nil, auth: auth)
        _ = try await httpClient.send(signed)
    }

    public func uploadObject(bucketName: String, objectName: String, fileURL: URL, contentType: String?, using auth: OCIAuthenticationConfig, progress: @escaping @Sendable (Double) -> Void) async throws {
        let namespace = try await resolveNamespace(using: auth)
        let data = try Data(contentsOf: fileURL)
        var request = URLRequest(url: try OCIEndpointBuilder.objectURL(region: auth.region, namespace: namespace, bucketName: bucketName, objectName: objectName))
        request.httpMethod = "PUT"
        request.setValue(contentType ?? "application/octet-stream", forHTTPHeaderField: "content-type")
        let signed = try signer.sign(request, bodyData: data, auth: auth)
        _ = try await httpClient.upload(signed, bodyData: data, progress: progress)
    }

    public func downloadObject(bucketName: String, objectName: String, destinationURL: URL, using auth: OCIAuthenticationConfig, progress: @escaping @Sendable (Double) -> Void) async throws {
        let namespace = try await resolveNamespace(using: auth)
        var request = URLRequest(url: try OCIEndpointBuilder.objectURL(region: auth.region, namespace: namespace, bucketName: bucketName, objectName: objectName))
        request.httpMethod = "GET"
        let signed = try signer.sign(request, bodyData: nil, auth: auth)
        _ = try await httpClient.download(signed, to: destinationURL, progress: progress)
    }

    public func createPreAuthenticatedRequest(bucketName: String, request model: CreatePARRequestModel, using auth: OCIAuthenticationConfig) async throws -> PARSummary {
        let namespace = try await resolveNamespace(using: auth)
        let payload = CreatePARDTO(
            accessType: model.accessType.rawValue,
            bucketListingAction: model.bucketListingAction,
            name: model.name,
            objectName: model.objectName,
            timeExpires: SharedFormatters.formatISO8601WithFractional(model.expiresAt)
        )
        let body = try encoder.encode(payload)
        var request = URLRequest(url: try OCIEndpointBuilder.preAuthenticatedRequestsURL(region: auth.region, namespace: namespace, bucketName: bucketName))
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        let signed = try signer.sign(request, bodyData: body, auth: auth)
        let (data, _) = try await httpClient.send(signed)
        let dto = try decoder.decode(PARDTO.self, from: data)
        return mapPAR(dto, region: auth.region, bucketName: bucketName, namespace: namespace)
    }

    public func listPreAuthenticatedRequests(bucketName: String, using auth: OCIAuthenticationConfig) async throws -> [PARSummary] {
        let namespace = try await resolveNamespace(using: auth)
        var request = URLRequest(url: try OCIEndpointBuilder.preAuthenticatedRequestsURL(region: auth.region, namespace: namespace, bucketName: bucketName))
        request.httpMethod = "GET"
        let signed = try signer.sign(request, bodyData: nil, auth: auth)
        do {
            let (data, _) = try await httpClient.send(signed)
            let dtos = try decodePARList(from: data)
            return dtos.map { mapPAR($0, region: auth.region, bucketName: bucketName, namespace: namespace) }
        } catch {
            await logger.log(
                .warning,
                category: "PAR",
                message: L10n.string("service.par.remote_fallback"),
                metadata: [
                    "bucket": bucketName,
                    "reason": AppError.from(error).localizedDescription
                ]
            )
            return []
        }
    }

    public func deletePreAuthenticatedRequest(bucketName: String, parID: String, using auth: OCIAuthenticationConfig) async throws {
        let namespace = try await resolveNamespace(using: auth)
        var request = URLRequest(url: try OCIEndpointBuilder.preAuthenticatedRequestURL(region: auth.region, namespace: namespace, bucketName: bucketName, parID: parID))
        request.httpMethod = "DELETE"
        let signed = try signer.sign(request, bodyData: nil, auth: auth)
        _ = try await httpClient.send(signed)
    }

    private func resolveNamespace(using auth: OCIAuthenticationConfig) async throws -> String {
        if let namespace = auth.namespace, !namespace.isEmpty {
            return namespace
        }
        var request = URLRequest(url: try OCIEndpointBuilder.namespaceURL(region: auth.region))
        request.httpMethod = "GET"
        let signed = try signer.sign(request, bodyData: nil, auth: auth)
        let (data, _) = try await httpClient.send(signed)
        if let namespace = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !namespace.isEmpty {
            return namespace.replacingOccurrences(of: "\"", with: "")
        }
        throw AppError.authentication(L10n.string("error.object_storage.namespace_detect_failed"))
    }

    private func getBucketSummary(named bucketName: String, namespace: String, auth: OCIAuthenticationConfig) async throws -> BucketSummary {
        let details = try await getBucketDetails(named: bucketName, using: auth)
        return BucketSummary(
            id: details.name,
            name: details.name,
            namespace: namespace,
            compartmentID: details.compartmentID,
            createdAt: details.createdAt,
            etag: nil,
            publicAccessType: details.publicAccessType,
            storageTier: details.storageTier
        )
    }

    private func mapPAR(_ dto: PARDTO, region: String, bucketName: String, namespace: String) -> PARSummary {
        let fullURL = dto.accessURI.hasPrefix("http")
            ? dto.accessURI
            : "https://objectstorage.\(region).oraclecloud.com\(dto.accessURI)"
        return PARSummary(
            id: dto.id,
            name: dto.name,
            accessType: dto.accessType,
            timeCreated: dto.timeCreated,
            timeExpires: dto.timeExpires,
            objectName: dto.objectName,
            accessURI: dto.accessURI,
            fullPath: fullURL,
            bucketName: bucketName,
            namespace: namespace
        )
    }

    private func decodePARList(from data: Data) throws -> [PARDTO] {
        if data.isEmpty {
            return []
        }

        if let stringValue = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           stringValue.isEmpty || stringValue == "null" {
            return []
        }

        if let wrapped = try? decoder.decode(ListPARResponseDTO.self, from: data) {
            return wrapped.items
        }

        if let altWrapped = try? decoder.decode(ListPARAltResponseDTO.self, from: data) {
            return altWrapped.data
        }

        if let array = try? decoder.decode([PARDTO].self, from: data) {
            return array
        }

        if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let items = jsonObject["items"] as? [[String: Any]] {
                let normalized = try JSONSerialization.data(withJSONObject: items)
                return (try? decoder.decode([PARDTO].self, from: normalized)) ?? []
            }
            if let dataItems = jsonObject["data"] as? [[String: Any]] {
                let normalized = try JSONSerialization.data(withJSONObject: dataItems)
                return (try? decoder.decode([PARDTO].self, from: normalized)) ?? []
            }
        }

        throw AppError.parsing(L10n.string("error.object_storage.par_list_unexpected"))
    }

    private func parseHTTPDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.date(from: value)
    }
}

private struct BucketDTO: Codable {
    let id: String?
    let name: String
    let compartmentID: String?
    let timeCreated: Date?
    let publicAccessType: String?
    let storageTier: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case compartmentID = "compartmentId"
        case timeCreated
        case publicAccessType
        case storageTier
    }
}

private struct BucketDetailsDTO: Codable {
    let name: String
    let compartmentID: String?
    let timeCreated: Date?
    let storageTier: String?
    let versioning: String?
    let publicAccessType: String?
    let autoTiering: String?

    enum CodingKeys: String, CodingKey {
        case name
        case compartmentID = "compartmentId"
        case timeCreated
        case storageTier
        case versioning
        case publicAccessType
        case autoTiering
    }
}

private struct CreateBucketDTO: Codable {
    let compartmentID: String
    let name: String
    let publicAccessType: String
    let storageTier: String

    enum CodingKeys: String, CodingKey {
        case compartmentID = "compartmentId"
        case name
        case publicAccessType
        case storageTier
    }
}

private struct ListObjectsResponseDTO: Codable {
    let prefixes: [String]
    let objects: [ObjectDTO]
    let nextStartWith: String?
}

private struct ListObjectVersionsResponseDTO: Codable {
    let items: [ObjectVersionDTO]

    enum CodingKeys: String, CodingKey {
        case items = "objects"
    }
}

private struct ObjectDTO: Codable {
    let name: String
    let size: Int64?
    let timeModified: Date?
    let etag: String?
    let storageTier: String?
}

private struct ObjectVersionDTO: Codable {
    let name: String
    let size: Int64?
    let timeCreated: Date?
    let timeModified: Date?
    let etag: String?
    let versionID: String
    let isDeleteMarker: Bool?
    let storageTier: String?

    enum CodingKeys: String, CodingKey {
        case name
        case size
        case timeCreated
        case timeModified
        case etag
        case versionID = "versionId"
        case isDeleteMarker
        case storageTier
    }
}

private struct CreatePARDTO: Codable {
    let accessType: String
    let bucketListingAction: String?
    let name: String
    let objectName: String?
    let timeExpires: String
}

private struct ListPARResponseDTO: Codable {
    let items: [PARDTO]
}

private struct ListPARAltResponseDTO: Codable {
    let data: [PARDTO]
}

private struct PARDTO: Codable {
    let id: String
    let name: String
    let accessType: String
    let timeCreated: Date?
    let timeExpires: Date?
    let objectName: String?
    let accessURI: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case accessType
        case timeCreated
        case timeExpires
        case objectName
        case accessURI = "accessUri"
    }
}
