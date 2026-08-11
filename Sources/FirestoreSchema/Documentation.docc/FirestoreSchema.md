# ``FirestoreSchema``

A macro DSL that turns a Firestore database's shape into Swift types.

## Overview

Firestore has no schema of its own, so the structure lives wherever you last wrote a path string.
This module lets you declare it once — collections, subcollections, and the model stored in each —
and generates the paths and `CodingKeys` from that declaration. Reading a document returns the
model type without a `as:` argument, because the collection already knows it.

The module re-exports `FirestoreServer`, so importing it brings `FirestoreClient` and the query
types along with the DSL.

### The two halves

``FirestoreModel(keyStrategy:)`` describes one document. It generates `CodingKeys`, adds
`Codable` and `Sendable` conformance, and marks the type as ``FirestoreModelProtocol`` — the
constraint that stops a plain `Codable` struct from being wired into a collection by accident.
Field names come from the property names, adjusted by ``FirestoreKeyStrategy``, with per-property
overrides from ``Field(_:)``, ``Field(strategy:)``, and ``FieldIgnore()``.

``FirestoreSchema()`` describes the database. Each nested ``Collection(_:model:)`` becomes both a
static path API and an instance accessor; nesting one inside another makes it a subcollection.

- **Static side**: `Schema.Users.collectionPath`, `Schema.Users.documentPath("uid")`,
  `Schema.Users.Books.collectionPath("uid")`. No client involved — useful for logging, security
  rules, and tests.
- **Instance side**: `schema.users.document("uid")`, which carries the client and the model type
  with it.

### Getting started

Declare the models, then the database that stores them:

```swift
import FirestoreSchema

@FirestoreModel(keyStrategy: .snakeCase)
struct User {
    let id: String
    let displayName: String        // display_name
    let createdAt: Date            // created_at

    @Field("email_address")        // an explicit name wins over the strategy
    let email: String

    @FieldIgnore                   // never written, never read; needs a default
    var sessionToken: String? = nil
}

@FirestoreModel
struct Book {
    let id: String
    let title: String

    @Field(strategy: .snakeCase)   // only this property is converted
    let pageCount: Int
}

@FirestoreSchema
struct Schema {
    @Collection("users", model: User.self)
    enum Users {
        @Collection("books", model: Book.self)
        enum Books {}
    }
}
```

`@FirestoreModel` decides field names at compile time; `FirestoreConfiguration` also has a key
strategy that is applied at run time by the encoder and decoder. Setting both means converting
twice, so pick one — the macro when the mapping belongs to the model, the configuration when it is
a database-wide convention.

Give the schema a client and the operations come from ``FirestoreCollectionProtocol`` and
``FirestoreDocumentProtocol``:

```swift
let client = try await FirestoreClient(.auto)
let schema = Schema(client: client)

// Result type comes from the collection's model, so there is no `as: User.self`.
let user = try await schema.users.document("user123").get()

try await schema.users.document("user123").create(data: newUser)
try await schema.users.document("user123").set(data: editedUser)
try await schema.users.document("user123").delete()
```

`set(data:)` sends the encoded model as a `PATCH` with no update mask, so it becomes the document's
complete set of fields: anything the model leaves out is dropped, and a document that is not there
is created. `update(data:)` sends the same fields with an update mask naming them, so a field the
model does not describe survives, and it asserts the document exists rather than creating one.

### Subcollections

A nested `@Collection` needs the parent document ID, which the accessor takes as an argument:

```swift
// users/user123/books
let books = schema.users.document("user123").books

let book = try await books.document("book456").get()
try await books.document("book456").create(data: newBook)

// The same path, without a client, for a log line or a test:
Schema.Users.Books.collectionPath("user123")   // "users/user123/books"
```

The instance accessors are generated three collection levels deep. The static path API has no such
limit, so a fourth level — `@Collection("notes", model: Note.self)` nested inside a `Chapters`
collection inside `Books` — is reached by handing its generated path to the client:

```swift
let path = Schema.Users.Books.Chapters.Notes.documentPath("user123", "book456", "ch1", "note1")
let note = try await client.getDocument(client.document(path), as: Note.self)
```

### Queries and pagination

``FirestoreCollectionProtocol/query()`` starts a `Query` already bound to the model, and
``FirestoreCollectionProtocol/execute(_:)`` runs it. Only the top level of a `filter` block holds a
single condition; combining several means wrapping them in `And` or `Or` explicitly:

```swift
let recentAdults = try await schema.users.execute(
    schema.users.query()
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
        .limit(to: 50)
)
```

`Field("…")` takes the Firestore field name as a string, which means it does not know about the key
strategy. `@FirestoreModel` also generates a `Fields` namespace of `FieldPath` constants holding
the *resolved* names, so `whereField` and `order(by:)` stay correct when the mapping changes:

```swift
let newest = try await schema.users.execute(
    schema.users.query()
        // User.Fields.createdAt is FieldPath<User>("created_at"), from .snakeCase above.
        .order(by: User.Fields.createdAt, direction: .descending)
        .limit(to: 20)
)
```

Listing a whole collection is paginated, and `getAll` returns the page token alongside the
documents rather than looping for you:

```swift
var cursor: String?
repeat {
    let page = try await schema.users.getAll(pageSize: 100, pageToken: cursor)
    for user in page.documents {
        print(user.displayName)
    }
    cursor = page.nextPageToken
} while cursor != nil
```

### Errors

Reads throw `FirestoreError`. A document that is not there is a `404` from the REST API turned
into `FirestoreError.notFound(path:)` — not a `nil` result — so absence has to be caught:

```swift
func loadUser(id: String) async throws -> User? {
    do {
        return try await schema.users.document(id).get()
    } catch let error as FirestoreError {
        logger.debug("user \(id) unavailable: \(error.description)")
        return nil
    }
}
```

## Topics

### Defining models

- ``FirestoreModel(keyStrategy:)``
- ``Field(_:)``
- ``Field(strategy:)``
- ``FieldIgnore()``
- ``FirestoreKeyStrategy``
- ``FirestoreModelProtocol``

### Defining a schema

- ``FirestoreSchema()``
- ``Collection(_:model:)``
- ``FirestoreSchemaProtocol``

### Working with collections and documents

- ``FirestoreCollectionProtocol``
- ``FirestoreDocumentProtocol``
- ``FirestoreCollection``
- ``FirestoreDocument``
