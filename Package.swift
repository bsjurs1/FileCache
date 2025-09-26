// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "URLCache",
    platforms: [
        .iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v8)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "URLCache",
            targets: ["URLCache"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing", branch: "main")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "URLCache",
            path: "Sources/URLCache"
        ),
        .testTarget(
            name: "URLCacheTests",
            dependencies: [
                "URLCache",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/URLCacheTests"
        ),
    ]
)
