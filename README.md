# swift-firebase-server

Firestore, Cloud Storage, and Firebase Auth for server-side Swift, spoken directly over the REST APIs — no Firebase Admin SDK.

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-macOS%2014+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

English | [日本語](./README.ja.md)

## Features

- **Type-safe schema DSL** — `@FirestoreSchema`, `@Collection`, and `@FirestoreModel` generate the collection paths and model types, so `schema.users.document(id).get()` comes back as a `User` with no cast and no string paths.
- **CodingKeys you don't write** — `@FirestoreModel` handles `snakeCase` conversion, per-field `@Field` keys, and `@FieldIgnore` for properties that never reach Firestore.
- **REST-native** — no Admin SDK and no C dependencies, so it builds and runs on Linux. Credentials resolve themselves from the Cloud Run metadata server, a local `gcloud` login, or an emulator.
- **Declarative queries** — a result-builder `FilterBuilder` for filters, ordering, and pagination.
- **ID token verification** — Firebase Auth ID tokens verified against Google's public keys, which are fetched once and cached.
- **Eventarc payloads** — CloudEvents from Firestore triggers and Auth user creation decoded into Swift types.

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
struct Schema {
    @Collection("users", model: User.self)
    enum Users {}
}

// Picks up Cloud Run, local gcloud, or the emulator on its own.
let client = try await FirestoreClient(.auto)
let schema = Schema(client: client)

let user = try await schema.users.document("user123").get()

let activeUsers = try await schema.users.execute(
    schema.users.query().filter { Field("status") == "active" }
)
```

## Documentation

The full API reference is published from the DocC catalogs:

- [FirestoreServer](https://no-problem-dev.github.io/swift-firebase-server/documentation/firestoreserver/) — Firestore REST client, paths, and queries
- [FirestoreSchema](https://no-problem-dev.github.io/swift-firebase-server/documentation/firestoreschema/) — schema and model macros
- [FirebaseStorageServer](https://no-problem-dev.github.io/swift-firebase-server/documentation/firebasestorageserver/) — Cloud Storage client
- [FirebaseStorageSchema](https://no-problem-dev.github.io/swift-firebase-server/documentation/firebasestorageschema/) — Storage schema macros
- [FirebaseAuthServer](https://no-problem-dev.github.io/swift-firebase-server/documentation/firebaseauthserver/) — ID token verification and the Admin API
- [EventarcServer](https://no-problem-dev.github.io/swift-firebase-server/documentation/eventarcserver/) — CloudEvents payload decoding

Longer-form guides live in [`documentation/`](documentation/README.md), including a
[Swift macro reference](documentation/references/macros/README.md) for the DSL internals. Those
guides are written in Japanese.

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-firebase-server.git", from: "2.0.0")
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

## Requirements

- macOS 14+ (Linux is supported for deployment targets such as Cloud Run)
- Swift 6.2+
- Xcode 16+

## Contributing

Bug reports and pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) for how to
build, test, and release.

## License

MIT License — see [LICENSE](LICENSE) for details.
