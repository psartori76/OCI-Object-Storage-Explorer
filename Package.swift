// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "OCIObjectStorageExplorer",
    platforms: [
        .macOS(.v13),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "OCIExplorerCore",
            targets: ["OCIExplorerCore"]
        ),
        .library(
            name: "OCIExplorerServices",
            targets: ["OCIExplorerServices"]
        ),
        .library(
            name: "OCIExplorerShared",
            targets: ["OCIExplorerShared"]
        ),
        .library(
            name: "OCIExploreriOSUI",
            targets: ["OCIExploreriOSUI"]
        ),
        .executable(
            name: "OCIObjectStorageExplorer",
            targets: ["OCIExplorerApp"]
        )
    ],
    targets: [
        .target(
            name: "OCIExplorerCore"
        ),
        .target(
            name: "OCIExplorerServices",
            dependencies: ["OCIExplorerCore"]
        ),
        .target(
            name: "OCIExplorerShared",
            dependencies: ["OCIExplorerCore", "OCIExplorerServices"]
        ),
        .target(
            name: "OCIExploreriOSUI",
            dependencies: ["OCIExplorerCore", "OCIExplorerServices", "OCIExplorerShared"],
            path: "Sources/OCIExploreriOSUI"
        ),
        .executableTarget(
            name: "OCIExplorerApp",
            dependencies: ["OCIExplorerCore", "OCIExplorerServices", "OCIExplorerShared"],
            path: "Sources/OCIExplorerApp",
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "OCIExplorerServicesTests",
            dependencies: ["OCIExplorerCore", "OCIExplorerServices"]
        ),
        .testTarget(
            name: "OCIExplorerAppTests",
            dependencies: ["OCIExplorerCore", "OCIExplorerServices", "OCIExplorerShared", "OCIExplorerApp"]
        )
    ],
    swiftLanguageModes: [.v6]
)
