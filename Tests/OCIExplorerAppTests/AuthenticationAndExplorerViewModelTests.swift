import Foundation
import XCTest
@testable import OCIExplorerApp
@testable import OCIExplorerCore
@testable import OCIExplorerServices

@MainActor
final class AuthenticationAndExplorerViewModelTests: XCTestCase {
    func testConnectPersistsProfileAndResolvesNamespace() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let profileStore = ProfileStore(baseDirectory: tempDirectory)
        let keychain = InMemoryKeychainService()
        let service = MockObjectStorageService()
        let logger = AppLogger()

        let viewModel = AuthenticationViewModel(
            profileStore: profileStore,
            keychainService: keychain,
            objectStorageService: service,
            identityService: MockIdentityService(),
            logger: logger
        )

        viewModel.draft.profileName = "Sandbox"
        viewModel.draft.tenancyOCID = "ocid1.tenancy.oc1..aaaa"
        viewModel.draft.userOCID = "ocid1.user.oc1..bbbb"
        viewModel.draft.fingerprint = "11:22:33"
        viewModel.draft.region = "sa-saopaulo-1"
        viewModel.draft.privateKeyPEM = "-----BEGIN PRIVATE KEY-----\nZmFrZQ==\n-----END PRIVATE KEY-----"
        viewModel.draft.defaultCompartmentOCID = "ocid1.compartment.oc1..cccc"
        viewModel.draft.rememberMe = true

        let session = try await viewModel.connect()
        let savedProfiles = try profileStore.loadProfiles()
        let savedSecrets = try keychain.loadSecrets(for: session.profile.id)

        XCTAssertEqual(session.connection.resolvedNamespace, "detected-namespace")
        XCTAssertEqual(savedProfiles.count, 1)
        XCTAssertFalse(savedSecrets?.privateKeyPEM.isEmpty ?? true)
    }

    func testExplorerFiltersObjectsBySearchText() async {
        let service = MockObjectStorageService()
        let logger = AppLogger()
        let session = ExplorerSession(
            profile: AuthProfile(
                name: "Default",
                tenancyOCID: "ocid1.tenancy.oc1..aaaa",
                userOCID: "ocid1.user.oc1..bbbb",
                fingerprint: "11:22:33",
                region: "sa-saopaulo-1",
                namespace: "ns",
                defaultCompartmentOCID: "ocid1.compartment.oc1..cccc",
                rememberMe: false
            ),
            auth: OCIAuthenticationConfig(
                tenancyOCID: "ocid1.tenancy.oc1..aaaa",
                userOCID: "ocid1.user.oc1..bbbb",
                fingerprint: "11:22:33",
                region: "sa-saopaulo-1",
                namespace: "ns",
                compartmentOCID: "ocid1.compartment.oc1..cccc",
                privateKeyPEM: "pem"
            ),
            connection: ConnectionTestResult(resolvedNamespace: "ns", region: "sa-saopaulo-1", message: "ok")
        )

        let coordinator = TransferCoordinator(service: service, auth: session.auth, logger: logger)
        let viewModel = ExplorerViewModel(
            session: session,
            service: service,
            parHistoryStore: PARHistoryStore(),
            transferCoordinator: coordinator,
            logger: logger
        )

        await viewModel.bootstrap()
        viewModel.searchText = "json"

        XCTAssertEqual(viewModel.selectedRegionCode, "sa-saopaulo-1")
        XCTAssertTrue(viewModel.availableRegions.contains(where: { $0.regionCode == "sa-saopaulo-1" }))
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertEqual(viewModel.filteredItems.first?.name, "payload.json")
    }

    func testExplorerPreservesMultipleSelection() async {
        let service = MockObjectStorageService()
        let logger = AppLogger()
        let session = ExplorerSession(
            profile: AuthProfile(
                name: "Default",
                tenancyOCID: "ocid1.tenancy.oc1..aaaa",
                userOCID: "ocid1.user.oc1..bbbb",
                fingerprint: "11:22:33",
                region: "sa-saopaulo-1",
                namespace: "ns",
                defaultCompartmentOCID: "ocid1.compartment.oc1..cccc",
                rememberMe: false
            ),
            auth: OCIAuthenticationConfig(
                tenancyOCID: "ocid1.tenancy.oc1..aaaa",
                userOCID: "ocid1.user.oc1..bbbb",
                fingerprint: "11:22:33",
                region: "sa-saopaulo-1",
                namespace: "ns",
                compartmentOCID: "ocid1.compartment.oc1..cccc",
                privateKeyPEM: "pem"
            ),
            connection: ConnectionTestResult(resolvedNamespace: "ns", region: "sa-saopaulo-1", message: "ok")
        )

        let coordinator = TransferCoordinator(service: service, auth: session.auth, logger: logger)
        let viewModel = ExplorerViewModel(
            session: session,
            service: service,
            parHistoryStore: PARHistoryStore(),
            transferCoordinator: coordinator,
            logger: logger
        )

        await viewModel.bootstrap()
        viewModel.updateSelection(["payload.json", "notes.txt"])

        XCTAssertEqual(viewModel.selectedObjects.count, 2)
        XCTAssertEqual(viewModel.selectedFileItems.count, 2)
        XCTAssertTrue(viewModel.canDownloadSelection)
        XCTAssertNil(viewModel.selectedObject)
    }

    func testExplorerCanChangeRegionAndReloadBuckets() async {
        let service = MockObjectStorageService()
        service.bucketNamesByRegion = [
            "sa-saopaulo-1": ["bucket-br"],
            "us-ashburn-1": ["bucket-us"]
        ]

        let session = ExplorerSession(
            profile: AuthProfile(
                name: "Default",
                tenancyOCID: "ocid1.tenancy.oc1..aaaa",
                userOCID: "ocid1.user.oc1..bbbb",
                fingerprint: "11:22:33",
                region: "sa-saopaulo-1",
                namespace: "ns",
                defaultCompartmentOCID: "ocid1.compartment.oc1..cccc",
                rememberMe: false
            ),
            auth: OCIAuthenticationConfig(
                tenancyOCID: "ocid1.tenancy.oc1..aaaa",
                userOCID: "ocid1.user.oc1..bbbb",
                fingerprint: "11:22:33",
                region: "sa-saopaulo-1",
                namespace: "ns",
                compartmentOCID: "ocid1.compartment.oc1..cccc",
                privateKeyPEM: "pem"
            ),
            connection: ConnectionTestResult(resolvedNamespace: "ns", region: "sa-saopaulo-1", message: "ok")
        )

        let coordinator = TransferCoordinator(service: service, auth: session.auth, logger: AppLogger())
        let viewModel = ExplorerViewModel(
            session: session,
            service: service,
            parHistoryStore: PARHistoryStore(),
            transferCoordinator: coordinator,
            logger: AppLogger()
        )

        await viewModel.bootstrap()
        await viewModel.changeRegion(to: "us-ashburn-1")

        XCTAssertEqual(viewModel.selectedRegionCode, "us-ashburn-1")
        XCTAssertEqual(viewModel.buckets.first?.name, "bucket-us")
        XCTAssertTrue(service.listBucketsRegions.contains("us-ashburn-1"))
    }
}

private final class InMemoryKeychainService: KeychainServiceProtocol, @unchecked Sendable {
    private var storage: [UUID: AuthProfileSecrets] = [:]

    func storeSecrets(_ secrets: AuthProfileSecrets, for profileID: UUID) throws {
        storage[profileID] = secrets
    }

    func loadSecrets(for profileID: UUID) throws -> AuthProfileSecrets? {
        storage[profileID]
    }

    func deleteSecrets(for profileID: UUID) throws {
        storage.removeValue(forKey: profileID)
    }

    func duplicateSecrets(from sourceProfileID: UUID, to destinationProfileID: UUID) throws {
        storage[destinationProfileID] = storage[sourceProfileID]
    }
}

private final class MockObjectStorageService: OCIObjectStorageServiceProtocol, @unchecked Sendable {
    var listBucketsRegions: [String] = []
    var bucketNamesByRegion: [String: [String]] = [:]

    func testConnection(using auth: OCIAuthenticationConfig) async throws -> ConnectionTestResult {
        ConnectionTestResult(resolvedNamespace: "detected-namespace", region: auth.region, message: "Conexão OK")
    }

    func listBuckets(using auth: OCIAuthenticationConfig) async throws -> [BucketSummary] {
        listBucketsRegions.append(auth.region)
        let bucketNames = bucketNamesByRegion[auth.region] ?? ["bucket-a"]
        return bucketNames.map {
            BucketSummary(id: $0, name: $0, namespace: auth.namespace ?? "ns", compartmentID: nil, createdAt: .now)
        }
    }

    func createBucket(_ request: CreateBucketRequestModel, using auth: OCIAuthenticationConfig) async throws -> BucketSummary {
        BucketSummary(id: request.name, name: request.name, namespace: auth.namespace ?? "ns", compartmentID: request.compartmentID, createdAt: .now)
    }

    func deleteBucket(named bucketName: String, using auth: OCIAuthenticationConfig) async throws {}

    func getBucketDetails(named bucketName: String, using auth: OCIAuthenticationConfig) async throws -> BucketDetails {
        BucketDetails(name: bucketName, namespace: auth.namespace ?? "ns", compartmentID: auth.compartmentOCID, createdAt: .now, storageTier: "Standard", versioning: "Disabled", publicAccessType: "NoPublicAccess", autoTiering: "Disabled")
    }

    func listObjects(bucketName: String, prefix: String, using auth: OCIAuthenticationConfig, start: String?) async throws -> ObjectListingPage {
        ObjectListingPage(
            prefix: prefix,
            items: [
                ObjectBrowserItem(name: "docs", fullPath: "docs/", isFolder: true),
                ObjectBrowserItem(name: "payload.json", fullPath: "payload.json", isFolder: false, size: 512, modifiedAt: .now, etag: "etag-1", storageTier: "Standard"),
                ObjectBrowserItem(name: "notes.txt", fullPath: "notes.txt", isFolder: false, size: 256, modifiedAt: .now, etag: "etag-2", storageTier: "Standard")
            ],
            nextStartWith: nil
        )
    }

    func metadataForObject(bucketName: String, objectName: String, using auth: OCIAuthenticationConfig) async throws -> ObjectMetadata {
        ObjectMetadata(name: objectName, size: 512, contentType: "application/json", modifiedAt: .now, etag: "etag", storageTier: "Standard")
    }

    func listObjectVersions(bucketName: String, objectName: String, using auth: OCIAuthenticationConfig) async throws -> [ObjectVersionSummary] {
        [
            ObjectVersionSummary(
                name: objectName,
                versionID: "version-a",
                size: 512,
                modifiedAt: .now,
                timeCreated: .now,
                etag: "etag-version-a",
                storageTier: "Standard",
                isDeleteMarker: false,
                isCurrent: true
            )
        ]
    }

    func deleteObject(bucketName: String, objectName: String, using auth: OCIAuthenticationConfig) async throws {}

    func uploadObject(bucketName: String, objectName: String, fileURL: URL, contentType: String?, using auth: OCIAuthenticationConfig, progress: @escaping @Sendable (Double) -> Void) async throws {
        progress(1)
    }

    func downloadObject(bucketName: String, objectName: String, destinationURL: URL, using auth: OCIAuthenticationConfig, progress: @escaping @Sendable (Double) -> Void) async throws {
        progress(1)
    }

    func createPreAuthenticatedRequest(bucketName: String, request: CreatePARRequestModel, using auth: OCIAuthenticationConfig) async throws -> PARSummary {
        PARSummary(id: "par-1", name: request.name, accessType: request.accessType.rawValue, timeCreated: .now, timeExpires: request.expiresAt, objectName: request.objectName, accessURI: "/p/demo", fullPath: "https://example.com/p/demo")
    }

    func listPreAuthenticatedRequests(bucketName: String, using auth: OCIAuthenticationConfig) async throws -> [PARSummary] {
        []
    }

    func deletePreAuthenticatedRequest(bucketName: String, parID: String, using auth: OCIAuthenticationConfig) async throws {}
}

private final class MockIdentityService: OCIIdentityServiceProtocol, @unchecked Sendable {
    func listSubscribedRegions(using auth: OCIAuthenticationConfig) async throws -> [OCIRegion] {
        [
            OCIRegion(regionCode: "sa-saopaulo-1", regionKey: "GRU", regionName: "sa-saopaulo-1", status: "READY", isHomeRegion: false),
            OCIRegion(regionCode: "us-ashburn-1", regionKey: "IAD", regionName: "us-ashburn-1", status: "READY", isHomeRegion: true)
        ]
    }
}
