# swift-firebase-server

Firebase REST API client for server-side Swift (Firestore & Cloud Storage & Auth)

🌐 English | **[日本語](README.md)**

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-macOS%2014+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## What You Can Do

- Firestore document CRUD operations
- Cloud Storage file upload & download
- Firebase Auth ID token verification
- Type-safe collection path generation
- Declarative query building

## Features

- **Swift Macro DSL** - Type-safe schema and model definitions with `@FirestoreSchema`, `@Collection`, `@FirestoreModel`
- **Auto-generated CodingKeys** - `@FirestoreModel` supports `snakeCase` conversion and `@Field` custom keys
- **Native REST API** - Direct access from server-side Swift without Firebase Admin SDK
- **FilterBuilder DSL** - Declarative query syntax with Result Builders

## Quick Start

```swift
import FirestoreServer
import FirestoreSchema

@FirestoreModel(keyStrategy: .snakeCase)
struct User {
    let id: String
    let displayName: String
    let email: String
}

@FirestoreSchema
enum Schema {
    @Collection("users", model: User.self)
    enum Users {
        @Collection("posts", model: Post.self)
        enum Posts {}
    }
}

let client = FirestoreClient(projectId: "my-project")
let userRef = try client.document(Schema.Users.documentPath("user123"))
let user: User = try await client.getDocument(userRef, as: User.self)
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
| [Getting Started](documentation/getting-started.md) | Setup and quick start |
| [Firestore Document Operations](documentation/firestore/document-operations.md) | CRUD operations |
| [Firestore Queries](documentation/firestore/queries.md) | Filters, sorting, pagination |
| [Firestore Schema Definition](documentation/firestore/schema-definition.md) | @FirestoreSchema macro |
| [Firestore Model Definition](documentation/firestore/model-definition.md) | @FirestoreModel macro |
| [Storage File Operations](documentation/storage/file-operations.md) | Upload & download |
| [Storage Schema Definition](documentation/storage/schema-definition.md) | @StorageSchema macro |
| [Auth Token Verification](documentation/auth/token-verification.md) | ID token verification |

### 📚 API Reference (DocC)

- [FirestoreServer](https://no-problem-dev.github.io/swift-firebase-server/firestoreserver/documentation/firestoreserver/) - Firestore REST API client
- [FirestoreSchema](https://no-problem-dev.github.io/swift-firebase-server/firestoreschema/documentation/firestoreschema/) - Type-safe schema DSL
- [FirebaseStorageServer](https://no-problem-dev.github.io/swift-firebase-server/firebasestorageserver/documentation/firebasestorageserver/) - Cloud Storage client
- [FirebaseStorageSchema](https://no-problem-dev.github.io/swift-firebase-server/firebasestorageschema/documentation/firebasestorageschema/) - Type-safe Storage schema DSL
- [FirebaseAuthServer](https://no-problem-dev.github.io/swift-firebase-server/firebaseauthserver/documentation/firebaseauthserver/) - ID token verification

### 🔧 Technical Reference

- [Swift Macro Reference](documentation/references/macros/README.md) - Comprehensive macro reference

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
