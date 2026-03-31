import Foundation
import OCIExplorerCore

public protocol OCIObjectStorageServiceProtocol: Sendable {
    func testConnection(using auth: OCIAuthenticationConfig) async throws -> ConnectionTestResult
    func listBuckets(using auth: OCIAuthenticationConfig) async throws -> [BucketSummary]
    func createBucket(_ request: CreateBucketRequestModel, using auth: OCIAuthenticationConfig) async throws -> BucketSummary
    func deleteBucket(named bucketName: String, using auth: OCIAuthenticationConfig) async throws
    func getBucketDetails(named bucketName: String, using auth: OCIAuthenticationConfig) async throws -> BucketDetails
    func listObjects(bucketName: String, prefix: String, using auth: OCIAuthenticationConfig, start: String?) async throws -> ObjectListingPage
    func listObjectVersions(bucketName: String, objectName: String, using auth: OCIAuthenticationConfig) async throws -> [ObjectVersionSummary]
    func metadataForObject(bucketName: String, objectName: String, using auth: OCIAuthenticationConfig) async throws -> ObjectMetadata
    func deleteObject(bucketName: String, objectName: String, using auth: OCIAuthenticationConfig) async throws
    func uploadObject(bucketName: String, objectName: String, fileURL: URL, contentType: String?, using auth: OCIAuthenticationConfig, progress: @escaping @Sendable (Double) -> Void) async throws
    func downloadObject(bucketName: String, objectName: String, destinationURL: URL, using auth: OCIAuthenticationConfig, progress: @escaping @Sendable (Double) -> Void) async throws
    func createPreAuthenticatedRequest(bucketName: String, request: CreatePARRequestModel, using auth: OCIAuthenticationConfig) async throws -> PARSummary
    func listPreAuthenticatedRequests(bucketName: String, using auth: OCIAuthenticationConfig) async throws -> [PARSummary]
    func deletePreAuthenticatedRequest(bucketName: String, parID: String, using auth: OCIAuthenticationConfig) async throws
}
