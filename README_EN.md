# swift-firebase-server

Firebase REST API client for server-side Swift (Firestore & Cloud Storage & Auth)

🌐 English | **[日本語](README.md)**

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-macOS%2014+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

📚 **API Reference (DocC)**
- [FirestoreServer](https://no-problem-dev.github.io/swift-firebase-server/firestoreserver/documentation/firestoreserver/) - Firestore REST API client
- [FirestoreSchema](https://no-problem-dev.github.io/swift-firebase-server/firestoreschema/documentation/firestoreschema/) - Type-safe schema DSL
- [FirebaseStorageServer](https://no-problem-dev.github.io/swift-firebase-server/firebasestorageserver/documentation/firebasestorageserver/) - Cloud Storage client
- [FirebaseStorageSchema](https://no-problem-dev.github.io/swift-firebase-server/firebasestorageschema/documentation/firebasestorageschema/) - Type-safe Storage schema DSL
- [FirebaseAuthServer](https://no-problem-dev.github.io/swift-firebase-server/firebaseauthserver/documentation/firebaseauthserver/) - ID token verification

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
- **Cloud Storage Support** - Type-safe file paths with `@StorageSchema`, `@Folder`, `@Object`
- **Firebase Auth Support** - ID token verification for server-side authentication
- **Full REST API Support** - Direct server-side access without Firebase Admin SDK
- **Swift Concurrency** - Async/await API
- **Type-safe Queries** - Build filters, sorts, and pagination with type safety
- **Codable Integration** - Custom Encoder/Decoder for Firestore value types

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-firebase-server.git", .upToNextMajor(from: "1.0.0"))
]

// Add to target
.target(
    name: "YourApp",
    dependencies: [
        // Firestore
        .product(name: "FirestoreServer", package: "swift-firebase-server"),
        .product(name: "FirestoreSchema", package: "swift-firebase-server"),
        // Cloud Storage
        .product(name: "FirebaseStorageServer", package: "swift-firebase-server"),
        .product(name: "FirebaseStorageSchema", package: "swift-firebase-server"),
        // Firebase Auth
        .product(name: "FirebaseAuthServer", package: "swift-firebase-server"),
    ]
)
```

## Firestore

#### 1. Define Schema

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

#### 2. Initialize Client

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

#### 3. Document Operations

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

#### 4. Subcollection Access

```swift
// Get user's posts
let posts: [Post] = try await schema.users("userId").posts
    .query(as: Post.self)
    .get()

// Add post
try await schema.users("userId").posts("postId").set(newPost)
```

#### 5. Queries

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

#### Low-level API

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

#### Firestore Value Types

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

## Cloud Storage

Cloud Storage REST API client with macro-based type-safe path construction.

#### 1. Define Schema

```swift
import FirebaseStorageSchema

@StorageSchema
struct AppStorage {
    @Folder("images")
    struct Images {
        @Folder("users")
        struct Users {
            @Object("profile")
            struct Profile {}

            @Object("avatar")
            struct Avatar {}
        }

        @Folder("products")
        struct Products {
            @Object("thumbnail")
            struct Thumbnail {}
        }
    }

    @Folder("documents")
    struct Documents {
        @Object("report")
        struct Report {}
    }
}
```

#### 2. Initialize Client

```swift
import FirebaseStorageServer

// Production
let client = StorageClient(
    projectId: "your-project-id",
    bucket: "your-bucket.appspot.com"
)

// Emulator
let config = StorageConfiguration.emulator(
    projectId: "your-project-id",
    bucket: "your-bucket"
)
let client = StorageClient(configuration: config)
```

#### 3. Type-safe Path Construction

```swift
let storage = AppStorage(client: client)

// Path: "images/users/user123.jpg"
let profilePath = storage.images.users.profile("user123", .jpg)

// Path: "images/products/prod456.png"
let thumbnailPath = storage.images.products.thumbnail("prod456", .png)

// Path: "documents/report001.pdf"
let reportPath = storage.documents.report("report001", .pdf)
```

#### 4. File Operations

```swift
let path = storage.images.users.profile("user123", .jpg)

// Upload
let object = try await path.upload(
    data: imageData,
    authorization: token
)

// Download
let data = try await path.download(authorization: token)

// Get metadata
let metadata = try await path.getMetadata(authorization: token)

// Delete
try await path.delete(authorization: token)

// Get public URL
let url = path.publicURL
```

#### Low-level API

Without macros, you can use `StorageClient` directly:

```swift
let client = StorageClient(projectId: "my-project", bucket: "my-bucket")

// Upload
let object = try await client.upload(
    data: imageData,
    path: "images/photo.jpg",
    contentType: "image/jpeg",
    authorization: token
)

// Download
let data = try await client.download(
    path: "images/photo.jpg",
    authorization: token
)

// Delete
try await client.delete(path: "images/photo.jpg", authorization: token)

// Public URL
let url = client.publicURL(for: "images/photo.jpg")
```

#### Supported File Formats

`FileExtension` enum provides common file formats with Content-Type mapping:

| Category | Extensions |
|----------|------------|
| Images | `.jpg`, `.jpeg`, `.png`, `.gif`, `.webp`, `.heic`, `.svg`, `.bmp` |
| Documents | `.pdf`, `.doc`, `.docx`, `.xls`, `.xlsx`, `.ppt`, `.pptx`, `.txt`, `.csv` |
| Video | `.mp4`, `.mov`, `.avi`, `.mkv`, `.webm` |
| Audio | `.mp3`, `.wav`, `.aac`, `.m4a`, `.ogg`, `.flac` |
| Data | `.json`, `.xml`, `.yaml` |
| Archives | `.zip`, `.tar`, `.gz`, `.rar` |

## Firebase Auth

Firebase ID token verification client. Verify ID tokens sent from clients and authenticate users.

#### 1. Initialize Client

```swift
import FirebaseAuthServer

// Production
let authClient = AuthClient(projectId: "your-project-id")

// Emulator
let config = AuthConfiguration.emulator(projectId: "your-project-id")
let authClient = AuthClient(configuration: config)
```

#### 2. Verify ID Token

```swift
// Verify token directly
let verifiedToken = try await authClient.verifyIDToken(idToken)
print("User ID: \(verifiedToken.uid)")
print("Email: \(verifiedToken.email ?? "none")")

// Verify from Authorization header (for middleware use)
let authHeader = request.headers["Authorization"].first ?? ""
let verifiedToken = try await authClient.verifyAuthorizationHeader(authHeader)
```

#### 3. Verified Token Information

```swift
let token = try await authClient.verifyIDToken(idToken)

// Basic information
token.uid              // Firebase UID
token.email            // Email address (optional)
token.emailVerified    // Email verified flag
token.name             // User name (optional)
token.picture          // Profile picture URL (optional)
token.phoneNumber      // Phone number (optional)

// Authentication information
token.authTime         // Authentication time
token.issuedAt         // Token issued time
token.expiresAt        // Token expiration time
token.signInProvider   // Sign-in provider ("google.com", "apple.com", etc.)
```

#### 4. Vapor Middleware Example

```swift
import Vapor
import FirebaseAuthServer

struct FirebaseAuthMiddleware: AsyncMiddleware {
    let authClient: AuthClient

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let authHeader = request.headers["Authorization"].first else {
            throw Abort(.unauthorized, reason: "Missing authorization header")
        }

        do {
            let verifiedToken = try await authClient.verifyAuthorizationHeader(authHeader)
            // Store user ID in request
            request.storage[UserIDKey.self] = verifiedToken.uid
            return try await next.respond(to: request)
        } catch let error as AuthError {
            throw Abort(.unauthorized, reason: error.description)
        }
    }
}
```

#### 5. Error Handling

```swift
do {
    let token = try await authClient.verifyIDToken(idToken)
} catch AuthError.tokenMissing {
    // Authorization header is missing
} catch AuthError.tokenExpired(let expiredAt) {
    // Token has expired
} catch AuthError.tokenInvalid(let reason) {
    // Token format is invalid
} catch AuthError.signatureInvalid {
    // Signature is invalid
} catch AuthError.userNotFound {
    // User ID is empty
}

// Error code (Go backend compatible)
let errorCode = error.errorCode  // "AUTH_TOKEN_EXPIRED", etc.
```

#### Error Codes

| Error | Code | Description |
|-------|------|-------------|
| `tokenMissing` | `AUTH_TOKEN_MISSING` | Authorization header is missing |
| `tokenInvalid` | `AUTH_TOKEN_INVALID` | Token format is invalid |
| `tokenExpired` | `AUTH_TOKEN_EXPIRED` | Token has expired |
| `verificationFailed` | `AUTH_VERIFICATION_FAILED` | Verification failed |
| `userNotFound` | `AUTH_USER_NOT_FOUND` | User ID is empty |

## Requirements

- macOS 14+
- Swift 6.2+
- Xcode 16+

## License

MIT License - See [LICENSE](LICENSE) for details

## For Developers

- 🚀 **Release Process**: [Release Process Guide](RELEASE_PROCESS.md) - Steps to release a new version

## Support

- 📚 API Reference (DocC): [FirestoreServer](https://no-problem-dev.github.io/swift-firebase-server/firestoreserver/documentation/firestoreserver/) | [FirestoreSchema](https://no-problem-dev.github.io/swift-firebase-server/firestoreschema/documentation/firestoreschema/) | [FirebaseStorageServer](https://no-problem-dev.github.io/swift-firebase-server/firebasestorageserver/documentation/firebasestorageserver/) | [FirebaseStorageSchema](https://no-problem-dev.github.io/swift-firebase-server/firebasestorageschema/documentation/firebasestorageschema/) | [FirebaseAuthServer](https://no-problem-dev.github.io/swift-firebase-server/firebaseauthserver/documentation/firebaseauthserver/)
- 🐛 [Issue Reports](https://github.com/no-problem-dev/swift-firebase-server/issues)
- 💬 [Discussions](https://github.com/no-problem-dev/swift-firebase-server/discussions)

---

Made with ❤️ by [NOPROBLEM](https://github.com/no-problem-dev)
