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
        .package(url: "https://github.com/pfllc/SwiftUtilities.git", from: "0.1.0"),
        .package(url: "https://github.com/trevorsheridan/AsyncReactiveSequences.git", .upToNextMajor(from: "0.1.0"))
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "AsyncSimpleStore",
            dependencies: [
                .product(name: "Utilities", package: "SwiftUtilities"),
                .product(name: "AsyncReactiveSequences", package: "AsyncReactiveSequences"),
            ]
        ),
        .testTarget(
            name: "AsyncSimpleStoreTests",
            dependencies: ["AsyncSimpleStore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
