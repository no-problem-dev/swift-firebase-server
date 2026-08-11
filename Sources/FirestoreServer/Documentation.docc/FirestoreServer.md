# ``FirestoreServer``

A Firestore client for server-side Swift, built on the REST API.

## Overview

``FirestoreClient`` speaks to Firestore over HTTPS with AsyncHTTPClient — no gRPC, no Firebase
Admin SDK, no C dependencies. It drops into a Vapor or Hummingbird service without pulling in a
second networking stack, and it works the same against the Firebase emulator as against
production.

Everything below the client is a value type. Paths validate themselves, references combine into
paths, and ``Query`` is immutable, so each builder call hands back a new query rather than mutating
the one you had.

### What the REST semantics mean for your code

A few behaviours follow from the API rather than from this library, and they are the ones that
surprise people:

- **A missing document is an error, not an empty result.** Firestore answers `GET` on an absent
  document with `404`, which becomes ``FirestoreError/notFound(path:)``. Reads that may legitimately
  come up empty need a `catch`, not an `if let`.
- **Create refuses to overwrite.** ``FirestoreClient/createDocument(_:data:)`` posts to the parent
  collection with `?documentId=`, so an ID already in use comes back as `409` →
  ``FirestoreError/alreadyExists(path:)``.
- **Update is not a merge.** ``FirestoreClient/updateDocument(_:data:)`` sends `PATCH` with the
  encoded model and no `updateMask`, so Firestore takes those fields as the document's complete set
  — anything the model leaves out is dropped. Pass a full value, or use the
  `updateDocument(_:fields:)` overload to send exactly the fields you mean.
- **Queries are not transactional and not paged.** ``FirestoreClient/runQuery(_:)`` posts
  `:runQuery` with no transaction and no read time, so it sees the database as of whenever the
  server got to it and two consecutive runs can disagree. The whole result also arrives in one
  response, bounded by the 10 MiB the client reads — bound large queries with `limit(to:)` and a
  cursor. Matching nothing is an empty array, not an error.
- **Every returned document must decode.** One document that does not fit the type fails the whole
  call. Where a collection holds mixed shapes, ``FirestoreClient/runQueryRaw(_:)`` and
  ``FirestoreClient/getDocument(_:)`` hand back ``FirestoreDocument`` untouched.

### Getting started

Which `GCPConfiguration` case you pass decides whether initialization is asynchronous, because only
`.auto` has to go fetch credentials:

```swift
import FirestoreServer

// Cloud Run's metadata server, or local `gcloud` credentials.
let firestore = try await FirestoreClient(.auto)

// A named database rather than "(default)".
let analytics = try await FirestoreClient(.autoWithDatabase(databaseId: "analytics"))

// The Firebase emulator: plain HTTP on localhost:8080, any token accepted.
let local = FirestoreClient(.emulator(projectId: "demo-project"))

// A token you obtained yourself — a user's own credentials, or an exchange you performed.
let scoped = FirestoreClient(.explicit(projectId: "my-project", token: accessToken))
```

The access token is captured at initialization and never refreshed, so a long-running process
should build a fresh client as its token approaches expiry.

If your Swift property names and your Firestore field names differ by convention rather than
one at a time, set the strategies once on the client and stop thinking about it:

```swift
let firestore = try await FirestoreClient(
    .auto,
    keyEncodingStrategy: .convertToSnakeCase,   // displayName -> display_name on write
    keyDecodingStrategy: .convertFromSnakeCase  // display_name -> displayName on read
)
```

Both strategies also take `.custom` for a mapping neither case covers. They apply inside
``FirestoreEncoder`` and ``FirestoreDecoder``, which the client uses for every typed call.

### Reading and writing documents

References are built from the client and compose in both directions — ``CollectionReference/document(_:)``
down, ``DocumentReference/parent`` and ``DocumentReference/collection(_:)`` across:

```swift
struct User: Codable, Sendable {
    let id: String
    let displayName: String
    let status: String
    let age: Int
}

let users = firestore.collection("users")
let userRef = users.document("user123")
let books = userRef.collection("books")

// Or from a whole path at once. This throws `PathError` when the segment count is
// wrong for a document — an even number of segments, at least two.
let bookRef = try firestore.document("users/user123/books/book456")
```

> Important: ``FirestoreClient/collection(_:)`` traps on an invalid path rather than throwing.
> Pass it a collection ID, or a path with an odd number of segments; a value coming from outside
> your code should go through ``CollectionPath/init(_:)`` first, which reports the problem as
> ``PathError``.

The typed calls encode and decode for you:

```swift
try await firestore.createDocument(userRef, data: newUser)

let loaded = try await firestore.getDocument(userRef, as: User.self)

try await firestore.updateDocument(userRef, data: editedUser)

try await firestore.deleteDocument(userRef)
```

When a document holds fields your model does not describe — a server timestamp, a counter another
process owns — drop to the untyped overloads, which take and return ``FirestoreValue`` directly:

```swift
// Writes exactly these two fields, leaving nothing else to guess about.
try await firestore.updateDocument(userRef, fields: [
    "status": .string("suspended"),
    "suspendedAt": .timestamp(Date()),
])

let raw = try await firestore.getDocument(userRef)
print(raw.documentId ?? "", raw.updateTime ?? Date.distantPast)
```

### Queries

``Query`` is built by chaining, and ``Query/filter(_:)`` opens the result-builder DSL. Its top
level holds exactly one filter, so several conditions have to be wrapped in ``And`` or ``Or``
explicitly — which also makes the precedence of a mixed expression unambiguous:

```swift
let query = users.query(as: User.self)
    .filter {
        And {
            Field("status") == "active"
            Field("age") >= 18
            Or {
                Field("role") == "admin"
                Field("role") == "moderator"
            }
        }
    }
    .order(by: FieldPath<User>("age"), direction: .descending)
    .limit(to: 50)

let adults = try await firestore.runQuery(query)
```

The DSL also accepts `if` and `if let`, so an optional filter does not need a second query:

```swift
let query = users.query(as: User.self).filter {
    And {
        Field("status") == "active"
        if let minimumAge {
            Field("age") >= minimumAge
        }
    }
}
```

``Field`` covers the comparison operators plus the array and membership tests —
``Field/contains(_:)``, ``Field/containsAny(_:)``, ``Field/in(_:)``, ``Field/notIn(_:)`` — and the
null and NaN checks as ``Field/isNull``, ``Field/isNotNull``, ``Field/isNaN``, ``Field/isNotNaN``,
which become unary filters rather than comparisons against a value.

For a collection group query — the same collection ID at every depth in the database —
``Query/collectionGroup()`` switches the selector, leaving the rest of the query as it is:

```swift
// Every "chats" subcollection anywhere under the database.
let allChats = try await firestore.runQuery(
    firestore.collection("chats")
        .query(as: Chat.self)
        .collectionGroup()
        .order(by: FieldPath<Chat>("createdAt"), direction: .descending)
        .limit(to: 100)
)
```

### Paging through a collection

``FirestoreClient/listDocuments(in:as:pageSize:pageToken:)`` returns the page token beside the
documents rather than looping for you, so paging stays explicit:

```swift
var cursor: String?
repeat {
    let page = try await firestore.listDocuments(
        in: users,
        as: User.self,
        pageSize: 100,
        pageToken: cursor
    )
    for user in page.documents {
        print(user.displayName)
    }
    cursor = page.nextPageToken
} while cursor != nil
```

### Handling failures

``FirestoreError`` separates transport failures — carried in `.api` — from the encoding and
decoding failures this library raises itself, and every case renders through `description`:

```swift
func loadUser(id: String) async throws -> User? {
    do {
        return try await firestore.getDocument(users.document(id), as: User.self)
    } catch FirestoreError.decoding(let underlying) {
        // The document is there but does not match `User`. A data problem, not a miss.
        logger.error("user \(id) failed to decode: \(underlying)")
        throw FirestoreError.decoding(underlying: underlying)
    } catch let error as FirestoreError {
        // 404, 403, 429, and the rest arrive here.
        logger.debug("user \(id) unavailable: \(error.description)")
        return nil
    }
}
```

## Topics

### Essentials

- ``FirestoreClient``
- ``FirestoreConfiguration``

### References

- ``DocumentReference``
- ``CollectionReference``

### Paths

- ``DatabasePath``
- ``DocumentPath``
- ``CollectionPath``
- ``ResourcePath``
- ``PathSegment``

### Building queries

- ``Query``
- ``FirestoreQueryProtocol``
- ``Field``
- ``FieldPath``
- ``SortDirection``

### The filter DSL

- ``FilterBuilder``
- ``And``
- ``Or``
- ``AndFilterBuilder``
- ``OrFilterBuilder``

### Filters

- ``QueryFilterProtocol``
- ``FieldFilter``
- ``UnaryFilter``
- ``CompositeFilter``
- ``QueryFilter``
- ``FieldReference``
- ``FieldFilterOperator``
- ``UnaryFilterOperator``
- ``CompositeFilterOperator``

### Query structure

- ``CollectionSelector``
- ``QueryOrder``
- ``QueryCursor``
- ``QueryProjection``

### Values and coding

- ``FirestoreValue``
- ``FirestoreValueConvertible``
- ``FirestoreDocument``
- ``FirestoreEncoder``
- ``FirestoreDecoder``
- ``KeyEncodingStrategy``
- ``KeyDecodingStrategy``

### Errors

- ``FirestoreError``
- ``PathError``
- ``FirestoreValueError``
- ``FirestoreDocumentError``
- ``FirestoreEncodingError``
- ``FirestoreDecodingError``
