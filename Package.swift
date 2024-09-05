// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AsyncSimpleStore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "AsyncSimpleStore",
            targets: ["AsyncSimpleStore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/trevorsheridan/SwiftUtilities.git", branch: "main"),
        .package(url: "https://github.com/trevorsheridan/ReAsync.git", branch: "main"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "AsyncSimpleStore",
            dependencies: [
                .product(name: "Utilities", package: "SwiftUtilities"),
                .product(name: "ReAsync", package: "ReAsync"),
            ]
        ),
        .testTarget(
            name: "AsyncSimpleStoreTests",
            dependencies: ["AsyncSimpleStore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
