import Foundation

public enum OCIEndpointBuilder {
    public static func baseURL(region: String) throws -> URL {
        guard let url = URL(string: "https://objectstorage.\(region).oraclecloud.com") else {
            throw URLError(.badURL)
        }
        return url
    }

    public static func namespaceURL(region: String) throws -> URL {
        try baseURL(region: region).appending(path: "n")
    }

    public static func identityBaseURL(region: String) throws -> URL {
        guard let url = URL(string: "https://identity.\(region).oraclecloud.com") else {
            throw URLError(.badURL)
        }
        return url
    }

    public static func regionSubscriptionsURL(region: String, tenancyID: String) throws -> URL {
        var components = URLComponents(
            url: try identityBaseURL(region: region).appending(path: "20160918/regionSubscriptions"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "tenancyId", value: tenancyID)]
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        return url
    }

    public static func bucketsURL(region: String, namespace: String, compartmentID: String? = nil) throws -> URL {
        var components = URLComponents(url: try baseURL(region: region).appending(path: "n/\(namespace)/b"), resolvingAgainstBaseURL: false)
        if let compartmentID, !compartmentID.isEmpty {
            components?.queryItems = [URLQueryItem(name: "compartmentId", value: compartmentID)]
        }
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        return url
    }

    public static func bucketURL(region: String, namespace: String, bucketName: String) throws -> URL {
        try baseURL(region: region).appending(path: "n/\(namespace)/b/\(bucketName)")
    }

    public static func objectURL(region: String, namespace: String, bucketName: String, objectName: String) throws -> URL {
        var components = URLComponents(url: try baseURL(region: region), resolvingAgainstBaseURL: false)
        let encodedNamespace = encodePathSegment(namespace)
        let encodedBucket = encodePathSegment(bucketName)
        let encodedObject = encodeObjectPath(objectName)
        components?.percentEncodedPath = "/n/\(encodedNamespace)/b/\(encodedBucket)/o/\(encodedObject)"
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        return url
    }

    public static func listObjectsURL(
        region: String,
        namespace: String,
        bucketName: String,
        prefix: String,
        start: String? = nil,
        delimiter: String = "/"
    ) throws -> URL {
        var components = URLComponents(url: try baseURL(region: region).appending(path: "n/\(namespace)/b/\(bucketName)/o"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "prefix", value: prefix.isEmpty ? nil : prefix),
            URLQueryItem(name: "delimiter", value: delimiter),
            URLQueryItem(name: "fields", value: "name,size,timeModified,etag,storageTier")
        ]
        if let start, !start.isEmpty {
            components?.queryItems?.append(URLQueryItem(name: "start", value: start))
        }
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        return url
    }

    public static func objectVersionsURL(
        region: String,
        namespace: String,
        bucketName: String,
        objectName: String
    ) throws -> URL {
        var components = URLComponents(
            url: try baseURL(region: region).appending(path: "n/\(namespace)/b/\(bucketName)/objectversions"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "prefix", value: objectName),
            URLQueryItem(name: "fields", value: "name,size,timeCreated,timeModified,etag,versionId,isDeleteMarker,storageTier")
        ]
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        return url
    }

    public static func preAuthenticatedRequestsURL(region: String, namespace: String, bucketName: String) throws -> URL {
        try baseURL(region: region).appending(path: "n/\(namespace)/b/\(bucketName)/p")
    }

    public static func preAuthenticatedRequestURL(region: String, namespace: String, bucketName: String, parID: String) throws -> URL {
        try baseURL(region: region).appending(path: "n/\(namespace)/b/\(bucketName)/p/\(parID)")
    }

    private static func encodePathSegment(_ value: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static func encodeObjectPath(_ value: String) -> String {
        value
            .split(separator: "/", omittingEmptySubsequences: false)
            .map { encodePathSegment(String($0)) }
            .joined(separator: "/")
    }
}
