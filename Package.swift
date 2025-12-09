// swift-tools-version: 6.2

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "swift-firestore-server",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        // Core library (REST API client)
        .library(
            name: "FirestoreServer",
            targets: ["FirestoreServer"]
        ),
        // Schema DSL with macros
        .library(
            name: "FirestoreSchema",
            targets: ["FirestoreSchema"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.23.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
    ],
    targets: [
        // Core Firestore client
        .target(
            name: "FirestoreServer",
            dependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ]
        ),

        // Macro declarations and protocols
        .target(
            name: "FirestoreSchema",
            dependencies: [
                "FirestoreServer",
                "FirestoreMacros",
            ]
        ),

        // Macro implementations (compiler plugin)
        .macro(
            name: "FirestoreMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),

        // Tests
        .testTarget(
            name: "FirestoreServerTests",
            dependencies: ["FirestoreServer"]
        ),
        .testTarget(
            name: "FirestoreMacrosTests",
            dependencies: [
                "FirestoreSchema",
                "FirestoreMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
