# ``FirebaseStorageServer``

A Cloud Storage for Firebase client for server-side Swift, built on the JSON REST API.

## Overview

``StorageClient`` talks to the Cloud Storage JSON API over HTTPS with AsyncHTTPClient. There is no
gRPC dependency and no Firebase Admin SDK, so it drops into a Vapor or Hummingbird service without
pulling in a second networking stack.

One client is bound to one bucket for its lifetime — the bucket is fixed at initialization and
appears in every request path. Create a client per bucket if you use more than one.

### Choosing a credential source

The initializer takes a `GCPConfiguration`, and which case you pass decides whether initialization
is asynchronous:

```swift
// Cloud Run metadata server, or local `gcloud` credentials. Resolving them is a
// network call, so this initializer is async.
let storage = try await StorageClient(.auto, bucket: "my-bucket.firebasestorage.app")

// Firebase Storage emulator. No token is fetched, so no `await`.
let local = StorageClient(.emulator(projectId: "demo-project"), bucket: "my-bucket")

// A token you obtained yourself — a user's own credentials, or a workload identity
// exchange you already performed.
let scoped = StorageClient(
    .explicit(projectId: "my-project", token: accessToken),
    bucket: "my-bucket"
)
```

The token is captured at initialization and never refreshed, so a long-lived process should build
a fresh client when its access token approaches expiry.

### Reading and writing objects

``StorageClient/upload(data:path:contentType:)`` performs a single-request media upload and returns
the object's metadata, including the server-computed `size` and `md5Hash`. Downloads are collected
into memory, up to 100 MB.

```swift
let jpeg: Data = try makeThumbnail(from: original)

let object = try await storage.upload(
    data: jpeg,
    path: "images/users/\(userId)/avatar.jpg",
    contentType: "image/jpeg"
)
print("\(object.name) — \(object.size) bytes, md5 \(object.md5Hash ?? "n/a")")

let restored = try await storage.download(path: object.name)
```

Deleting one object throws on failure. Deleting many does not: ``StorageClient/deleteMultiple(paths:)``
walks the list in order, keeps going past failures, and hands back the ones that did not succeed —
which is what you want when you are tearing down a user's files and a single stale path should not
abort the rest.

```swift
let failures = await storage.deleteMultiple(paths: [
    "images/users/\(userId)/avatar.jpg",
    "documents/users/\(userId)/export.pdf",
])

for (path, error) in failures {
    logger.warning("could not delete \(path): \(error.description)")
}
```

### Handling failures

Every HTTP failure becomes a ``StorageError``. The transport-level cases are carried inside
`.api`, and the convenience constructors of the same names — ``StorageError/notFound(path:)``,
``StorageError/permissionDenied(message:)`` — build the matching value, so a missing object is a
`404` mapped to `.api(.notFound(path:))` rather than a `nil` return.

```swift
do {
    let metadata = try await storage.getMetadata(path: path)
    return metadata.size
} catch let error as StorageError {
    // Every case renders through `description`, including the wrapped API error.
    logger.error("storage: \(error.description)")
    return nil
}
```

### Public URLs

``StorageClient/publicURL(for:)`` composes the download URL for an object without a request. It is
emulator-aware: against the emulator it returns the local host and port, so the same code produces
a URL that works in both environments. Objects still need to be publicly readable for the URL to
resolve — the method builds an address, it does not grant access.

## Topics

### Essentials

- ``StorageClient``
- ``StorageConfiguration``

### Object metadata

- ``StorageObject``

### Errors

- ``StorageError``
