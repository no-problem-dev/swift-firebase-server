// swift-tools-version: 6.2

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "swift-firebase-server",
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
            name: "FirebaseStorageServer",
            targets: ["FirebaseStorageServer"]
        ),
        // Storage Schema DSL with macros
        .library(
            name: "FirebaseStorageSchema",
            targets: ["FirebaseStorageSchema"]
        ),
        // Firebase Auth client (ID token verification)
        .library(
            name: "FirebaseAuthServer",
            targets: ["FirebaseAuthServer"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.23.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
    ],
    targets: [
        // Internal shared module (not exposed as a product)
        .target(
            name: "Internal",
            dependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
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
            name: "FirebaseStorageServer",
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
            name: "FirebaseStorageSchema",
            dependencies: [
                "FirebaseStorageServer",
                "FirebaseStorageMacros",
            ]
        ),

        // Storage Macro implementations (compiler plugin)
        .macro(
            name: "FirebaseStorageMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),

        // Firebase Auth client (ID token verification)
        .target(
            name: "FirebaseAuthServer",
            dependencies: [
                "Internal",
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "_CryptoExtras", package: "swift-crypto"),
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
            name: "FirebaseStorageServerTests",
            dependencies: ["FirebaseStorageServer"]
        ),
        .testTarget(
            name: "FirebaseStorageMacrosTests",
            dependencies: [
                "FirebaseStorageSchema",
                "FirebaseStorageMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "FirebaseAuthServerTests",
            dependencies: ["FirebaseAuthServer"]
        ),
    ]
)
