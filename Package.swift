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
        // Cloud Storage client
        .library(
            name: "StorageServer",
            targets: ["StorageServer"]
        ),
        // Storage Schema DSL with macros
        .library(
            name: "StorageSchema",
            targets: ["StorageSchema"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.23.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
    ],
    targets: [
        // Internal shared module (not exposed as a product)
        .target(
            name: "Internal",
            dependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ]
        ),

        // Core Firestore client
        .target(
            name: "FirestoreServer",
            dependencies: [
                "Internal",
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ]
        ),

        // Cloud Storage client
        .target(
            name: "StorageServer",
            dependencies: [
                "Internal",
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

        // Firestore Macro implementations (compiler plugin)
        .macro(
            name: "FirestoreMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),

        // Storage Schema declarations and protocols
        .target(
            name: "StorageSchema",
            dependencies: [
                "StorageServer",
                "StorageMacros",
            ]
        ),

        // Storage Macro implementations (compiler plugin)
        .macro(
            name: "StorageMacros",
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
        .testTarget(
            name: "StorageServerTests",
            dependencies: ["StorageServer"]
        ),
        .testTarget(
            name: "StorageMacrosTests",
            dependencies: [
                "StorageSchema",
                "StorageMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
