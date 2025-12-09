# swift-firestore-server

Firestore REST API client for server-side Swift

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-macOS%2014+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

📚 **[API Reference (DocC)](https://no-problem-dev.github.io/swift-firestore-server/documentation/firestoreserver/)**

## Features

```swift
import FirestoreServer
import FirestoreSchema

// Type-safe schema definition with macros
@FirestoreSchema
struct AppSchema {
    @Collection("users")
    struct Users {
        @SubCollection("books")
        struct Books {}
    }
}

// Fluent API for document access
let client = FirestoreClient(projectId: "my-project", accessToken: token)
let schema = AppSchema(client: client)

// Get document
let user: User = try await schema.users("userId").get()

// Run query
let activeUsers = try await schema.users.query(as: User.self)
    .where("status", .equal, "active")
    .orderBy("createdAt", .descending)
    .limit(10)
    .get()
```

- **Vapor Independent** - Lightweight, based on AsyncHTTPClient
- **Macro-based DSL** - Type-safe access with `@FirestoreSchema`, `@Collection`, `@SubCollection`
- **Full REST API Support** - Direct server-side access without Firebase Admin SDK
- **Swift Concurrency** - Async/await API
- **Type-safe Queries** - Build filters, sorts, and pagination with type safety
- **Codable Integration** - Custom Encoder/Decoder for Firestore value types

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-firestore-server.git", .upToNextMajor(from: "1.0.0"))
]

// Add to target
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "FirestoreServer", package: "swift-firestore-server"),
        .product(name: "FirestoreSchema", package: "swift-firestore-server"),
    ]
)
```

## Basic Usage

### 1. Define Schema

```swift
import FirestoreSchema

@FirestoreSchema
struct AppSchema {
    @Collection("users")
    struct Users {
        @SubCollection("posts")
        struct Posts {}
    }

    @Collection("products")
    struct Products {}
}
```

### 2. Initialize Client

```swift
import FirestoreServer

// Use Google Cloud authentication token
let client = FirestoreClient(
    projectId: "your-project-id",
    accessToken: accessToken
)

// Custom database ID (optional)
let client = FirestoreClient(
    projectId: "your-project-id",
    databaseId: "custom-db",
    accessToken: accessToken
)
```

### 3. Document Operations

```swift
let schema = AppSchema(client: client)

// Get document
let user: User = try await schema.users("userId").get()

// Create document (with ID)
try await schema.users("newUserId").set(newUser)

// Create document (auto-generated ID)
let docId = try await schema.users.add(newUser)

// Update document
try await schema.users("userId").update(["name": "New Name"])

// Delete document
try await schema.users("userId").delete()
```

### 4. Subcollection Access

```swift
// Get user's posts
let posts: [Post] = try await schema.users("userId").posts
    .query(as: Post.self)
    .get()

// Add post
try await schema.users("userId").posts("postId").set(newPost)
```

### 5. Queries

```swift
// Query with conditions
let activeUsers = try await schema.users
    .query(as: User.self)
    .where("status", .equal, "active")
    .where("age", .greaterThanOrEqual, 18)
    .orderBy("createdAt", .descending)
    .limit(20)
    .get()

// Composite filter (AND)
let results = try await schema.products
    .query(as: Product.self)
    .where(.and([
        .field("category", .equal, "electronics"),
        .field("price", .lessThan, 1000)
    ]))
    .get()

// Composite filter (OR)
let results = try await schema.products
    .query(as: Product.self)
    .where(.or([
        .field("status", .equal, "sale"),
        .field("featured", .equal, true)
    ]))
    .get()

// Pagination
let (users, nextCursor) = try await schema.users
    .query(as: User.self)
    .orderBy("createdAt")
    .limit(10)
    .startAfter(cursor)
    .getWithCursor()
```

## Low-level API

Without macros, you can use `CollectionReference` and `DocumentReference` directly:

```swift
// Collection reference
let usersRef = client.collection("users")
let user: User = try await client.getDocument(usersRef.document("userId"))

// Query
let query = usersRef.query(as: User.self)
    .where("active", .equal, true)
let users = try await client.runQuery(query)
```

## Firestore Value Types

Custom Encoder/Decoder for Firestore REST API value types:

| Swift Type | Firestore Value Type |
|------------|---------------------|
| `String` | `stringValue` |
| `Int`, `Int64` | `integerValue` |
| `Double`, `Float` | `doubleValue` |
| `Bool` | `booleanValue` |
| `Date` | `timestampValue` |
| `Data` | `bytesValue` |
| `[T]` | `arrayValue` |
| `[String: T]` | `mapValue` |
| `nil` | `nullValue` |
| `GeoPoint` | `geoPointValue` |
| `DocumentReference` | `referenceValue` |

## Requirements

- macOS 14+
- Swift 6.2+
- Xcode 16+

## License

MIT License - See [LICENSE](LICENSE) for details

## For Developers

- 🚀 **Release Process**: [Release Process Guide](RELEASE_PROCESS.md) - Steps to release a new version

## Support

- 📚 [API Reference (DocC)](https://no-problem-dev.github.io/swift-firestore-server/documentation/firestoreserver/)
- 🐛 [Issue Reports](https://github.com/no-problem-dev/swift-firestore-server/issues)
- 💬 [Discussions](https://github.com/no-problem-dev/swift-firestore-server/discussions)

---

Made with ❤️ by [NOPROBLEM](https://github.com/no-problem-dev)
