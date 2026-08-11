# ``FirebaseStorageSchema``

A macro DSL that turns a Cloud Storage bucket's layout into Swift types.

## Overview

Object paths written as string literals drift: the upload site and the download site disagree, a
rename touches one of them, and nothing fails until production. This module lets you declare the
layout once, as nested Swift types, and generates the accessors that build every path from it.

The module re-exports `FirebaseStorageServer`, so importing it is enough to get `StorageClient`
along with the DSL.

### How the pieces map onto paths

Three macros describe a bucket:

- ``StorageSchema()`` on a `struct` makes it the root. It generates `client`, `init(client:)`, and
  one property per nested ``Folder(_:)``.
- ``Folder(_:)`` on a nested `struct` contributes one path segment — the string you pass — and
  generates accessors for the folders and objects nested inside it.
- ``Object(_:)`` on a nested `struct` generates a function taking an object ID and a
  ``FileExtension``, which resolves to a value you can upload, download, or delete through.

Two details of the generated names are worth knowing, because they are not what the macro
arguments suggest:

- **The accessor name comes from the type name, not from the macro's string.** `@Folder("images")
  struct Images` yields a property called `images`; the string `"images"` is what lands in the
  path. Naming the type `Pictures` would give you `schema.pictures` producing `images/…`.
- **An object's base name is not part of the path.** `@Object("profile") struct Profile` builds
  `{folders}/{objectId}.{ext}`, so `profile("user123", .png)` under `images/users` resolves to
  `images/users/user123.png` — the word `profile` names the accessor and nothing else.

### Getting started

Declare the bucket layout, then hand the type a client:

```swift
import FirebaseStorageSchema

@StorageSchema
struct AppStorage {
    @Folder("images")
    struct Images {
        @Folder("users")
        struct Users {
            @Object("avatar")
            struct Avatar {}
        }

        @Folder("books")
        struct Books {
            @Object("cover")
            struct Cover {}
        }
    }

    @Folder("exports")
    struct Exports {
        @Object("archive")
        struct Archive {}
    }
}

let client = try await StorageClient(.auto, bucket: "my-bucket.firebasestorage.app")
let storage = AppStorage(client: client)
```

Everything after that is method calls. The extension on ``StorageObjectPathProtocol`` puts the
object operations on the path value itself, and derives the `Content-Type` from the extension you
named — so an upload cannot disagree with its own filename:

```swift
let avatar = storage.images.users.avatar(userId, .jpg)

// `avatar.path` is "images/users/{userId}.jpg";
// Content-Type "image/jpeg" comes from the `.jpg` case, not from the caller.
let uploaded = try await avatar.upload(data: jpegData)
print("\(uploaded.name), \(uploaded.size) bytes")

let bytes = try await avatar.download()
let metadata = try await avatar.getMetadata()
let url = avatar.publicURL
```

Failures surface as `StorageError`, and a missing object is a `404` turned into
`StorageError.notFound(path:)` rather than an empty result:

```swift
func avatarSize(for userId: String) async -> Int64? {
    do {
        return try await storage.images.users.avatar(userId, .jpg).getMetadata().size
    } catch let error as StorageError {
        logger.info("no avatar for \(userId): \(error.description)")
        return nil
    } catch {
        return nil
    }
}
```

Because the path value carries its own client, a cleanup routine can be written against the schema
rather than against string paths:

```swift
func deleteUserFiles(userId: String, bookIds: [String]) async throws {
    try await storage.images.users.avatar(userId, .jpg).delete()
    try await storage.exports.archive(userId, .zip).delete()

    for bookId in bookIds {
        try await storage.images.books.cover(bookId, .png).delete()
    }
}
```

If you need to keep going past individual failures, collect the paths and pass them to
`StorageClient.deleteMultiple(paths:)` instead, which reports the ones that did not succeed
rather than throwing on the first.

## Topics

### Declaring a schema

- ``StorageSchema()``
- ``Folder(_:)``
- ``Object(_:)``

### Protocols the macros conform to

- ``StorageSchemaProtocol``
- ``StorageFolderProtocol``
- ``StorageObjectPathProtocol``

### File types

- ``FileExtension``
