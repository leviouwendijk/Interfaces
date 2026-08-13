// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Interfaces",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Interfaces",
            targets: ["Interfaces"]
        ),
        .executable(
            name: "gm",
            targets: [
                "gm",
            ]
        ),
        .executable(
            name: "itest",
            targets: [
                "InterfacesTestFlows",
            ]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/leviouwendijk/plate.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Primitives.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Indentation.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/ANSI.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Arguments.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Difference.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Processes.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/TestFlows.git",
            branch: "master"
        ),
    ],
    targets: [
        .target(
            name: "Interfaces",
            dependencies: [
                .product(name: "plate", package: "plate"),
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Indentation", package: "Indentation"),
                .product(name: "Arguments", package: "Arguments"),
                .product(name: "Difference", package: "Difference"),
                .product(name: "Processes", package: "Processes"),
            ],
            resources: [
                .process("Resources")
            ],
        ),
        .executableTarget(
            name: "gm",
            dependencies: [
                "Interfaces",
                .product(name: "ANSI", package: "ANSI"),
                .product(name: "Arguments", package: "Arguments"),
            ],
            path: "Sources/GitManagerCLI"
        ),
        .executableTarget(
            name: "InterfacesTestFlows",
            dependencies: [
                "Interfaces",
                .product(
                    name: "TestFlows",
                    package: "TestFlows"
                ),
            ]
        ),
    ]
)
