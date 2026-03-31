import Foundation
import XCTest
@testable import OCIExplorerCore
@testable import OCIExplorerServices

final class ProfileStoreTests: XCTestCase {
    func testSavesAndLoadsProfilesFromDisk() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = ProfileStore(baseDirectory: tempDirectory)

        let profile = AuthProfile(
            name: "Dev",
            tenancyOCID: "ocid1.tenancy.oc1..example",
            userOCID: "ocid1.user.oc1..example",
            fingerprint: "aa:bb:cc",
            region: "sa-saopaulo-1",
            namespace: "demo-namespace",
            defaultCompartmentOCID: "ocid1.compartment.oc1..example",
            privateKeyPathHint: "/tmp/key.pem",
            rememberMe: true
        )

        try store.upsert(profile)
        let loaded = try store.loadProfiles()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "Dev")
        XCTAssertEqual(loaded.first?.namespace, "demo-namespace")
        XCTAssertEqual(loaded.first?.rememberMe, true)
    }
}
