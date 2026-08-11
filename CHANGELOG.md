# Changelog

All notable changes to this project are recorded in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0] - 2026-08-11

### Breaking Changes

- **Split `updateDocument` into `setDocument` and `updateDocument`**
  - `setDocument(_:data:)` / `setDocument(_:fields:)`: the full replacement the old `updateDocument` did (no `updateMask`, no assumption that the document exists). If it does not exist, it is created
  - `updateDocument(_:data:)` / `updateDocument(_:fields:)`: a partial update that sends only the fields given in `updateMask.fieldPaths` and adds `currentDocument.exists=true`. Fields not given are left alone, and a missing document is a 404
  - Empty `fields` is now `FirestoreError.api(.invalidArgument)`, because it would otherwise turn into a maskless full replacement
  - `FirestoreSchema`'s `DocumentHandle.update(data:)` becomes a partial update; full replacement moves to `set(data:)`
- **Fixed the cursor boundaries being inverted**: `start(at:)` is `before: true` (inclusive), `start(after:)` is `before: false` (exclusive). `end(at:)` / `end(before:)` are unchanged
- **Verification happens in emulator mode too**: `IDTokenVerifier` checks `exp` / `iat` / `auth_time` / `aud` / `iss` / `sub` under an emulator configuration as well (only the signature cannot be verified). On the production path the signature is verified before the claims
- **Removed unused error cases**: `AuthError.verificationFailed`, `StorageError.fileTooLarge` / `.invalidContentType`, `GCPAuthError.providerNotInitialized` / `.environmentDetectionFailed`, `FirestoreEncodingError.unsupportedType`
- **Removed the unused `httpClientProvider` from `AuthAdminClient`**: it was held but `URLSession.shared` was used. `init(projectId:httpClientProvider:)` is removed too

### Fixed

- **Storage object names are percent-encoded in full**: `.urlPathAllowed` leaves `/`, `&` and `+` alone, so `o/{object}` did not resolve for a nested path, and the `name` sent on upload was wrong too
- **Storage path validation**: a name that is empty, `.`, `..`, or contains a newline is rejected with `StorageError.invalidPath` before the request goes out
- **`FirestoreEncoder` threw away nested containers**: fields disappeared silently when a hand-written `encode(to:)` used `nestedContainer` / `nestedUnkeyedContainer` / `superEncoder`. The internals were rebuilt to write back to the parent
- **`@FirestoreModel` treated a shorthand getter as a stored property**: `var x: Int { 1 }` grew `CodingKeys` and `Fields`. `static` and `class` properties are now excluded as well
- **Path segments are validated**: `.` / `..` / `__.*__` / over 1,500 bytes is `PathError.invalidCharacters`
- **Coding failures are wrapped in `FirestoreError`**: `.decoding` for a decode failure, `.encoding` for an encode failure
- **Query values are escaped**: `documentId` in `createDocument` and `pageToken` in `listDocuments`

## [1.1.0] - 2026-07-19

### Added

- A DocC catalogue.

### Changed

- The public errors are now proper error types.
- Documentation comments and DocC rewritten in Japanese; README unified as a Japanese and
  English pair; the prose in the `documentation/` guides made consistent.
- CI workflows synced to the standard SSOT template (tests + release-on-tag; the old
  auto-release is gone). DocC is built as combined documentation across every library, on
  macos-26 / Xcode 26 (Swift 6.2), and deployed to GitHub Pages via `actions/deploy-pages`.

### Fixed

- A missing `@_exported`.
- Corrected examples in the documentation.
- A process crash and the preconditions in the emulator integration tests.

## [1.0.17] - 2026-01-17

### Fixed

- **Linux compatibility**: added the `FoundationNetworking` import to `AuthAdminClient`
  - `URLRequest` and `URLSession.shared` are available on Linux
  - Resolves the build error on Cloud Run (Linux)

## [1.0.16] - 2026-01-17

### Added

- **Cloud Audit Logs support**: receive Firebase Auth events through Cloud Audit Logs
  - `CloudAuditLogEvent`: the Cloud Audit Logs event payload type
    - `isIdentityPlatformSignUp`: whether this is an Identity Platform sign-up event
    - `signedUpUserId`: the user ID of whoever signed up
    - `signedUpUserEmail`: the email of whoever signed up
  - `CloudEventHeaders.AuditLogEventType`: Cloud Audit Logs event type constants
  - `CloudEventHeaders.IdentityPlatformService`: Identity Platform service constants

- **Firestore Protobuf decoder**: handles the Protobuf form of Eventarc Firestore events
  - `FirestoreProtobufDecoder`: Protobuf binary → `FirestoreDocumentEvent`
  - The google-cloudevents proto definitions are bundled
  - Added the `swift-protobuf` dependency

- **Better initialisation**: types can be constructed programmatically
  - `AuthUserCreatedEvent`: added a public initialiser
  - `FirestoreValue`: added a public initialiser for each value type

### Dependencies

- Added `apple/swift-protobuf` 1.33.0+

### Example

```swift
// Cloud Audit Logs (Auth)
routes.webhook("user-created", body: CloudAuditLogEvent.self) { request in
    guard request.body.isIdentityPlatformSignUp else { return .badRequest }
    guard let userId = request.body.signedUpUserId else { return .badRequest }
    print("New user: \(userId)")
    return .ok
}

// Firestore Protobuf
routes.webhookRaw("chat-created") { request in
    let event = try FirestoreProtobufDecoder.decode(request.data)
    let params = event.extractPathParams(pattern: "users/{userId}/books/{bookId}/chats/{chatId}")
    print("Chat created: \(params)")
    return .ok
}
```

## [1.0.15] - 2026-01-17

### Added

- **EventarcServer module**: handling for Google Cloud Eventarc events (the CloudEvents format)
  - `CloudEventHeaders`: parses the CloudEvents HTTP headers
    - Handles `ce-type`, `ce-source`, `ce-id`, `ce-time`, `ce-subject`, `ce-specversion`
  - `AuthUserCreatedEvent`: the Firebase Auth user-created event payload
    - Fields such as `uid`, `email`, `displayName`, `metadata`
  - `FirestoreDocumentEvent`: a Firestore document event
    - Handles document created and document updated events
    - Supports `value` (the current value) and `oldValue` (the value before the update)
    - Path parameter extraction with `extractPathParams(pattern:)`

### Event type constants

```swift
CloudEventHeaders.AuthEventType.userCreated
// → "google.firebase.auth.user.v1.created"

CloudEventHeaders.FirestoreEventType.documentCreated
// → "google.cloud.firestore.document.v1.created"

CloudEventHeaders.FirestoreEventType.documentUpdated
// → "google.cloud.firestore.document.v1.updated"
```

### Path parameter extraction

```swift
let event: FirestoreDocumentEvent = ...
let params = event.extractPathParams(
    pattern: "users/{userId}/books/{bookId}/chats/{chatId}"
)
// params["userId"], params["bookId"], params["chatId"]
```

## [1.0.14] - 2026-01-17

### Added

- **AuthAdminClient** — user deletion through the Firebase Auth Admin API
  - `deleteUser(uid:)` — deletes the given user from Firebase Auth
  - Works with the Firebase Emulator
  - Idempotent (a user that does not exist is not an error)

### Fixed

- **AuthAdminClient** — uses the correct Firebase Auth REST API endpoint
  - `DELETE /accounts/{uid}` → `POST /accounts:delete`
  - The request body now carries `{ "localId": uid }`

## [1.0.13] - 2026-01-11

### Fixed

- **Firebase Storage Emulator** — file upload works against the emulator
  - `StorageObject.fromJSON()` falls back when there is no `id` field
  - The `id` is derived from the `generation` field the emulator returns
  - The `size` field is accepted as either a string or an integer
  - Error messages now include the actual response

## [1.0.12] - 2026-01-09

### Added

- **Type-safe FieldPath API** — field references in the Query API are type-safe
  - `FieldPath<Model>` — a generic struct tying a model to a field
  - The `@FirestoreModel` macro generates a `Fields` enum
  - `order(by:)`, `whereField()` and `select()` take a `FieldPath<T>`
  - A wrong field name is caught at compile time

### Changed

- **Query API signatures** — String replaced by FieldPath<T>
  - `order(by field: FieldPath<T>, direction:)`
  - `whereField(_ field: FieldPath<T>, isEqualTo:)` and so on

### Breaking Changes

- Query methods take a field as `Model.Fields.fieldName` rather than a `String`
  ```swift
  // Before
  .order(by: "updated_at", direction: .descending)

  // After
  .order(by: FirestoreBook.Fields.updatedAt, direction: .descending)
  ```

## [1.0.11] - 2026-01-07

### Fixed

- **Query.where() filter chaining** — chained `whereField()` calls overwrote each other
  - Before: only the last of several `whereField()` calls applied
  - After: several filters combine correctly with AND
  - e.g. `.whereField("timestamp", isGreaterThanOrEqualTo: from).whereField("timestamp", isLessThan: to)` now works

## [1.0.10] - 2026-01-02

### Changed

- **Swift 6.2**: supports the stable release of Swift 6.2
  - `swift-tools-version`: 6.0 → 6.2
  - `swift-syntax`: 600.0.0 → 602.0.0
  - `swift-crypto`: 3.0.0 → 4.0.0
  - Dependency requirements unified on `.upToNextMajor`

### Added

- **CI test workflow**: tests on macOS and Linux x86_64
  - macOS 15 (Swift 6.2)
  - Linux x86_64 (swift:6.2-bookworm)

## [1.0.9] - 2026-01-02

### Changed

- **Downgraded to Swift 6.0** — to avoid a compiler bug in Swift 6.2 nightly
  - Resolves the SIL verification error coming out of swift-configuration's FileProvider

## [1.0.8] - 2025-12-13

### Added
- **GCPConfiguration enum** — an exclusive API for authentication configuration
  - `.auto` — automatic detection of Cloud Run / local gcloud (async)
  - `.autoWithDatabase(databaseId:)` — for a custom database ID
  - `.emulator(projectId:)` — for the emulator (sync, token set automatically)
  - `.explicit(projectId:token:)` — an explicit projectId/token (sync)
- **GCPEnvironment actor** — a singleton for environment detection and credential retrieval
- **MetadataServerClient.fetchProjectId()** — gets the projectId automatically on Cloud Run
- **LocalAuthClient.fetchProjectId()** — gets the projectId automatically through the gcloud CLI
- **FirestoreClient key encoding/decoding** — `keyEncodingStrategy` / `keyDecodingStrategy` support

### Changed
- **@FirestoreSchema macro** — moved from enum-based to struct-based
  - `Schema.Instance(client:)` → direct initialisation with `Schema(client:)`
  - Implemented as a MemberMacro plus an ExtensionMacro
  - A more intuitive API, and type inference works
- **Documentation rewritten throughout** — unified on the schema-based API
  - New API examples in the `schema.users.document(id).get()` form
  - README, getting-started, document-operations, queries and schema-definition all updated

### Removed
- **AccessTokenProvider** — folded into GCPEnvironment
- **AutoAuthOperations** — the client holds the token now
- **The authorization parameter on every operation** — no longer needed

### Breaking Changes
- The initialiser signatures of FirestoreClient / StorageClient changed
- The authorization parameter is gone from every CRUD operation
- `@FirestoreSchema` applies to a `struct`, not an `enum`
- `Schema.Instance(client:)` → `Schema(client:)`

## [1.0.7] - 2025-12-12

### Added
- **@FirestoreModel macro** — a new macro for defining Firestore models
  - `keyStrategy: .snakeCase` converts camelCase → snake_case automatically
  - `@Field("custom_key")` names a field explicitly
  - `@FieldIgnore` excludes a property from encoding and decoding
  - Automatic conformance to `FirestoreModelProtocol` and `Codable`
  - Generates the `CodingKeys` enum

- **KeyStrategy** — a key conversion strategy at runtime
  - Configurable through `FirestoreConfiguration`
  - `.snakeCase` / `.useDefault` / `.custom`

- **Better documentation**
  - Added a Swift Macro reference (6 documents)
  - Added a "what you can do" section to the README
  - Renamed `docs/` → `documentation/` (separating it from the DocC output)

### Changed
- **@Collection macro improvements**
  - The `model:` parameter is now required, to tie the collection to a type
  - `typealias Model = T` is generated
  - Nesting is detected automatically (using `lexicalContext`)
  - Handles nesting three levels deep and beyond

### Removed
- **@SubCollection macro** — dropped, since nesting `@Collection` does the same thing

### Breaking Changes
- `@Collection` requires the `model:` parameter
- The `@SubCollection` macro is removed (nest `@Collection` instead)

## [1.0.6] - 2025-12-11

### Added
- **Automatic GCP authentication** — service account authentication managed automatically
  - `AccessTokenProvider` — gets an auth token according to the environment
    - Cloud Run: from the metadata server
    - Local: through the gcloud CLI
    - Emulator: returns a dummy token (authentication skipped)
  - `AutoAuthOperations` — Firestore operations that fetch the auth token themselves
  - `TokenCache` — token caching and automatic refresh
  - `MetadataServerClient` — a client for the Cloud Run metadata server
  - `LocalAuthClient` — a local authentication client using the gcloud CLI
  - `GCPAuthError` — the GCP authentication error type

- **Better Firebase Emulator support**
  - Detected automatically from `USE_FIREBASE_EMULATOR=true` or `FIRESTORE_EMULATOR_HOST`
  - Authentication is skipped in emulator mode (a dummy token is used)
  - The JWT header's `kid` field is optional (the emulator does not send one)
  - An empty signature part is supported (emulator tokens are unsigned)

### Changed
- **JWTDecoder** — `omittingEmptySubsequences: false`, to keep an empty signature part
- **JWTHeader** — the `kid` field is optional
- **IDTokenVerifier** — requires `kid` in production mode

### Affected modules
- FirestoreServer (AutoAuthOperations)
- FirebaseAuthServer (JWT)
- Internal (GCPAuth)

## [1.0.5] - 2025-12-10

### Fixed
- **Linux compatibility** — ByteBuffer → Data conversion works cross-platform
  - Added a `ByteBuffer.toData()` extension using `NIOFoundationCompat`
  - Replaced the macOS-only `Data(buffer:)` everywhere (17 places)
  - Building and running verified under Docker (Linux)
- **Swift 6 macro compatibility** — cleared the warnings on Swift 6.2

### Changed
- **Internal module** — added `ByteBufferExtensions.swift`
  - Added `swift-nio` as an explicit dependency
  - Imports the `NIOFoundationCompat` module

### Affected modules
- FirestoreServer (DocumentOperations, QueryOperations)
- FirebaseStorageServer (StorageClient)
- FirebaseAuthServer (PublicKeyCache)

## [1.0.4] - 2025-12-09

### Changed
- **Tightened access levels** — internal implementation types made `internal`, for better encapsulation
  - `JWTHeader`, `JWTPayload`, `JWTDecoder`, `DecodedJWT` (FirebaseAuthServer)
  - `FirestoreEncoder`, `FirestoreDecoder`, `FirestoreEncodingError`, `FirestoreDecodingError` (FirestoreServer)
  - `MacroError` (FirestoreMacros), `StorageMacroError` (FirebaseStorageMacros)

### Added
- **DocC documentation** — DocC generation set up for all five modules
  - FirestoreServer, FirestoreSchema
  - FirebaseStorageServer, FirebaseStorageSchema
  - FirebaseAuthServer
- The GitHub Actions workflow generates documentation for every target

### Documentation
- Direct links to each module's DocC documentation in the README

## [1.0.3] - 2025-12-09

### Changed
- **Repository renamed**: `swift-firestore-server` → `swift-firebase-server`
- **Packages renamed**: a consistent naming rule for the Firebase-related packages
  - `StorageServer` → `FirebaseStorageServer`
  - `StorageSchema` → `FirebaseStorageSchema`
  - `StorageMacros` → `FirebaseStorageMacros`
  - `AuthServer` → `FirebaseAuthServer`
- The Firestore packages are unchanged (FirestoreServer, FirestoreSchema, FirestoreMacros)

### Migration guide
Update your import statements:
```swift
// Before
import StorageServer
import StorageSchema
import AuthServer

// After
import FirebaseStorageServer
import FirebaseStorageSchema
import FirebaseAuthServer
```

## [1.0.2] - 2025-12-09

### Added
- **AuthServer** — a Firebase ID token verification client
  - `AuthClient` — the main entry point for ID token verification
  - `AuthConfiguration` — configuration for production and for the emulator
  - `IDTokenVerifier` — JWT verification and RS256 signature verification
  - `PublicKeyCache` — caches Google's public keys (honouring Cache-Control)
  - `VerifiedToken` — the verified token's information (uid, email, signInProvider and so on)
  - `JWTDecoder` — Base64URL decoding and JSON parsing
  - `AuthError` — error codes compatible with the Go backend

### Features
- ID token verification following Firebase's official documentation
  - JWT format verification (alg: RS256)
  - Claim verification (exp, iat, aud, iss, sub, auth_time)
  - RS256 signature verification (using SwiftCrypto)
- `verifyAuthorizationHeader()` — extracts and verifies the Bearer token
- Emulator mode — skips signature verification during development

### Dependencies
- Added `swift-crypto` 3.0.0+ (for RS256 signature verification)

## [1.0.1] - 2025-12-09

### Added
- **FilterBuilder DSL** — a declarative filter syntax built on ResultBuilder
  - `Field` — field references with operator overloads (`==`, `!=`, `<`, `<=`, `>`, `>=`)
  - `And` / `Or` — explicit logical grouping
  - `.contains()`, `.containsAny()`, `.in()`, `.notIn()` — array operations
  - `.isNull`, `.isNotNull`, `.isNaN`, `.isNotNaN` — NULL/NaN checks
  - `Query.filter { }` — adds filters using the DSL
- `FirestoreValueConvertible` — a protocol converting Swift standard types to FirestoreValue

- **StorageServer** — a Cloud Storage REST API client
  - `StorageClient` — upload, download, delete, and metadata
  - `StorageConfiguration` — production and emulator
  - `StorageObject` — the file metadata model
  - `StorageError` — comprehensive error handling

- **StorageSchema macro DSL** — type-safe storage schema definitions
  - `@StorageSchema` — the root schema definition macro
  - `@Folder("id")` — a hierarchical folder structure
  - `@Object("id")` — a file object path
  - `FileExtension` — Content-Type mappings for the common file formats
  - `StorageSchemaProtocol` / `StorageFolderProtocol` / `StorageObjectPathProtocol`

- **Internal (the shared module)**
  - `HTTPClientProvider` — shared HTTP client management
  - `APIError` — the shared Firebase REST API error
  - The `ServiceConfiguration` protocol and `EmulatorConfig`

### Changed
- Refactored FirestoreServer to use the Internal module
- `FirestoreError` wraps `APIError` for the shared error cases

### Removed
- `QueryResult<T>` — an unused struct

## [1.0.0] - 2025-12-09

### Added
- **The FirestoreServer core library**
  - `FirestoreClient` — the REST API client
  - `CollectionReference` / `DocumentReference` — the reference types
  - `CollectionPath` / `DocumentPath` / `DatabasePath` — the path types
  - `FirestoreEncoder` / `FirestoreDecoder` — Codable support
  - `FirestoreValue` — Firestore's value types in Swift

- **Query API**
  - `Query<T>` — a type-safe query builder
  - `FieldFilter` — field filters (equal, lessThan, greaterThan, in, arrayContains and so on)
  - `CompositeFilter` — composite filters (AND/OR)
  - `UnaryFilter` — unary filters (isNull, isNotNull)
  - `QueryOrder` — sorting (ascending, descending)
  - Pagination (limit, offset, startAt, startAfter, endAt, endBefore)

- **FirestoreSchema macro DSL**
  - `@FirestoreSchema` — the root schema definition macro
  - `@Collection("id")` — the collection definition macro
  - `@SubCollection("id")` — the subcollection definition macro
  - `FirestoreSchemaProtocol` / `FirestoreCollectionProtocol` / `FirestoreDocumentProtocol` — the protocol definitions

### Documentation
- A comprehensive README.md
- A release process guide
- Automatic DocC deployment through GitHub Actions

[Unreleased]: https://github.com/no-problem-dev/swift-firebase-server/compare/1.1.0...HEAD
[1.1.0]: https://github.com/no-problem-dev/swift-firebase-server/compare/v1.0.17...1.1.0
[1.0.17]: https://github.com/no-problem-dev/swift-firebase-server/compare/v1.0.16...v1.0.17
[1.0.16]: https://github.com/no-problem-dev/swift-firebase-server/compare/v1.0.15...v1.0.16
[1.0.15]: https://github.com/no-problem-dev/swift-firebase-server/compare/v1.0.14...v1.0.15
[1.0.14]: https://github.com/no-problem-dev/swift-firebase-server/compare/v1.0.13...v1.0.14
[1.0.13]: https://github.com/no-problem-dev/swift-firebase-server/compare/v1.0.12...v1.0.13
[1.0.12]: https://github.com/no-problem-dev/swift-firebase-server/compare/v1.0.11...v1.0.12
[1.0.11]: https://github.com/no-problem-dev/swift-firebase-server/compare/v1.0.10...v1.0.11
[1.0.10]: https://github.com/no-problem-dev/swift-firebase-server/compare/v1.0.9...v1.0.10
[1.0.9]: https://github.com/no-problem-dev/swift-firebase-server/compare/v1.0.8...v1.0.9
[1.0.8]: https://github.com/no-problem-dev/swift-firebase-server/compare/v1.0.7...v1.0.8
[1.0.7]: https://github.com/no-problem-dev/swift-firebase-server/compare/v1.0.6...v1.0.7
[1.0.6]: https://github.com/no-problem-dev/swift-firebase-server/compare/v1.0.5...v1.0.6
[1.0.5]: https://github.com/no-problem-dev/swift-firebase-server/compare/v1.0.4...v1.0.5
[1.0.4]: https://github.com/no-problem-dev/swift-firebase-server/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/no-problem-dev/swift-firebase-server/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/no-problem-dev/swift-firebase-server/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/no-problem-dev/swift-firebase-server/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/no-problem-dev/swift-firebase-server/releases/tag/v1.0.0

<!-- Auto-generated on 2025-12-09T11:13:37Z by release workflow -->

<!-- Auto-generated on 2025-12-09T12:06:18Z by release workflow -->

<!-- Auto-generated on 2025-12-09T12:23:23Z by release workflow -->

<!-- Auto-generated on 2025-12-09T12:59:33Z by release workflow -->

<!-- Auto-generated on 2025-12-09T22:22:46Z by release workflow -->

<!-- Auto-generated on 2025-12-10T21:42:19Z by release workflow -->

<!-- Auto-generated on 2025-12-12T13:39:16Z by release workflow -->

<!-- Auto-generated on 2025-12-12T23:29:43Z by release workflow -->

<!-- Auto-generated on 2026-01-02T04:47:00Z by release workflow -->

<!-- Auto-generated on 2026-01-02T07:31:27Z by release workflow -->

<!-- Auto-generated on 2026-01-06T23:11:12Z by release workflow -->

<!-- Auto-generated on 2026-01-09T11:34:16Z by release workflow -->

<!-- Auto-generated on 2026-01-10T23:33:17Z by release workflow -->

<!-- Auto-generated on 2026-01-17T10:56:40Z by release workflow -->

<!-- Auto-generated on 2026-01-17T12:07:05Z by release workflow -->

<!-- Auto-generated on 2026-01-17T12:48:28Z by release workflow -->
