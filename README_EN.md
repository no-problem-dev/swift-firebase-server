# swift-firebase-server

Firebase REST API client for server-side Swift (Firestore & Cloud Storage & Auth)

🌐 English | **[日本語](README.md)**

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-macOS%2014+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## Features

- **Vapor Independent** - Lightweight, based on AsyncHTTPClient
- **Macro-based DSL** - Type-safe access with `@FirestoreSchema`, `@Collection`
- **Cloud Storage Support** - Type-safe file paths with `@StorageSchema`, `@Folder`, `@Object`
- **Firebase Auth Support** - ID token verification for server-side authentication
- **Full REST API Support** - Direct access without Firebase Admin SDK
- **Swift Concurrency** - Async/await API
- **Type-safe Queries** - Declarative filter construction with FilterBuilder DSL

## Quick Start

```swift
import FirestoreServer
import FirestoreSchema

// Schema definition
@FirestoreSchema
struct AppSchema {
    @Collection("users", model: User.self)
    struct Users {
        @Collection("posts", model: Post.self)
        struct Posts {}
    }
}

// Initialize client
let client = FirestoreClient(projectId: "my-project")

// Get document
let userRef = try client.document("users/user123")
let user: User = try await client.getDocument(userRef, as: User.self, authorization: idToken)

// Run query
let usersRef = client.collection("users")
let activeUsers: [User] = try await client.runQuery(
    usersRef.query(as: User.self)
        .filter {
            And {
                Field("status") == "active"
                Field("age") >= 18
            }
        }
        .order(by: "createdAt", direction: .descending)
        .limit(to: 20),
    authorization: idToken
)
```

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-firebase-server.git", .upToNextMajor(from: "1.0.0"))
]

.target(
    name: "YourApp",
    dependencies: [
        .product(name: "FirestoreServer", package: "swift-firebase-server"),
        .product(name: "FirestoreSchema", package: "swift-firebase-server"),
        .product(name: "FirebaseStorageServer", package: "swift-firebase-server"),
        .product(name: "FirebaseStorageSchema", package: "swift-firebase-server"),
        .product(name: "FirebaseAuthServer", package: "swift-firebase-server"),
    ]
)
```

## Documentation

### 📖 Usage Guides

| Guide | Description |
|-------|-------------|
| [Getting Started](docs/getting-started.md) | Setup and quick start |
| [Firestore Document Operations](docs/firestore/document-operations.md) | CRUD operations |
| [Firestore Queries](docs/firestore/queries.md) | Conditional search |
| [Firestore FilterBuilder DSL](docs/firestore/filter-builder-dsl.md) | Declarative filter syntax |
| [Firestore Schema Definition](docs/firestore/schema-definition.md) | @FirestoreSchema macro |
| [Firestore Model Definition](docs/firestore/model-definition.md) | @FirestoreModel macro |
| [Storage File Operations](docs/storage/file-operations.md) | Upload & download |
| [Storage Schema Definition](docs/storage/schema-definition.md) | @StorageSchema macro |
| [Auth Token Verification](docs/auth/token-verification.md) | ID token verification |

### 📚 API Reference (DocC)

- [FirestoreServer](https://no-problem-dev.github.io/swift-firebase-server/firestoreserver/documentation/firestoreserver/) - Firestore REST API client
- [FirestoreSchema](https://no-problem-dev.github.io/swift-firebase-server/firestoreschema/documentation/firestoreschema/) - Type-safe schema DSL
- [FirebaseStorageServer](https://no-problem-dev.github.io/swift-firebase-server/firebasestorageserver/documentation/firebasestorageserver/) - Cloud Storage client
- [FirebaseStorageSchema](https://no-problem-dev.github.io/swift-firebase-server/firebasestorageschema/documentation/firebasestorageschema/) - Type-safe Storage schema DSL
- [FirebaseAuthServer](https://no-problem-dev.github.io/swift-firebase-server/firebaseauthserver/documentation/firebaseauthserver/) - ID token verification

### 🔧 Technical Reference

- [Swift Macro Reference](docs/references/macros/README.md) - Comprehensive macro reference
  - [Freestanding Macro](docs/references/macros/freestanding-macros.md) - Expression & Declaration macros
  - [Attached Macro](docs/references/macros/attached-macros.md) - Member, Peer, Accessor macros
  - [Package Structure](docs/references/macros/package-structure.md) - Package.swift, plugin registration
  - [SwiftSyntax API](docs/references/macros/swiftsyntax-api.md) - Syntax tree manipulation
  - [Diagnostics](docs/references/macros/diagnostics.md) - Error messages, Fix-Its
  - [Testing](docs/references/macros/testing.md) - assertMacroExpansion

## Requirements

- macOS 14+
- Swift 6.2+
- Xcode 16+

## License

MIT License - See [LICENSE](LICENSE) for details

## For Developers

- 🚀 **Release Process**: [Release Process Guide](RELEASE_PROCESS.md)

## Support

- 🐛 [Issue Reports](https://github.com/no-problem-dev/swift-firebase-server/issues)
- 💬 [Discussions](https://github.com/no-problem-dev/swift-firebase-server/discussions)

---

Made with ❤️ by [NOPROBLEM](https://github.com/no-problem-dev)
