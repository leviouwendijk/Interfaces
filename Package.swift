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
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Interfaces",
            dependencies: [
                .product(name: "plate", package: "plate"),
                .product(name: "Structures", package: "Structures"),
                .product(name: "Extensions", package: "Extensions"),
            ],
            resources: [
                .process("Resources")
            ],
        ),
        .testTarget(
            name: "InterfacesTests",
            dependencies: [
                "Interfaces",
                .product(name: "plate", package: "plate"),
                .product(name: "Structures", package: "Structures"),
                .product(name: "Extensions", package: "Extensions"),
            ]
        ),
    ]
)
