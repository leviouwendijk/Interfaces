// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Interfaces",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Interfaces",
            targets: ["Interfaces"]),
    ],
    dependencies: [
        // testing
        // .package(url: "https://github.com/swiftlang/swift-testing.git", from: "6.2.0"),
        .package(
            url: "https://github.com/leviouwendijk/plate.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Structures.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Extensions.git",
            branch: "master"
        ),

        .package(
            url: "https://github.com/leviouwendijk/Primitives.git",
            branch: "master"
        ),
    ],
    targets: [
        .target(
            name: "Interfaces",
            dependencies: [
                .product(name: "plate", package: "plate"),
                .product(name: "Structures", package: "Structures"),
                .product(name: "Extensions", package: "Extensions"),
                .product(name: "Primitives", package: "Primitives"),
            ],
            resources: [
                .process("Resources")
            ],
        ),
        .testTarget(
            name: "InterfacesTests",
            dependencies: [
                // testing
                // .product(name: "Testing", package: "swift-testing"),
                "Interfaces",
                .product(name: "plate", package: "plate"),
                .product(name: "Structures", package: "Structures"),
                .product(name: "Extensions", package: "Extensions"),
                .product(name: "Primitives", package: "Primitives"),
            ]
        ),
    ]
)
