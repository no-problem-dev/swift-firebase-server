# ``FirebaseAuthServer``

Verify Firebase ID tokens from server-side Swift, without the Firebase Admin SDK.

## Overview

A client app sends its Firebase ID token with each request; your server has to decide whether to
believe it. ``AuthClient`` answers that question locally. It fetches Google's signing certificates,
caches them for as long as Google says they are good for, and verifies the token against them — so
in the steady state a request costs no network round trip at all.

### What verification actually checks

``IDTokenVerifier`` runs these steps, in this order, and throws the first ``AuthError`` it hits:

1. The token splits into three JWT parts and both header and payload decode.
2. The header's `alg` is `RS256`. Anything else throws ``AuthError/unsupportedAlgorithm(_:)``.
3. The claims hold up, with five minutes of clock skew allowed by default:
   - `exp` is in the future — otherwise ``AuthError/tokenExpired(expiredAt:)``.
   - `iat` and `auth_time` are in the past.
   - `aud` equals your project ID.
   - `iss` equals `https://securetoken.google.com/{projectId}`.
   - `sub` is a non-empty string, which becomes ``VerifiedToken/uid``.
4. The RS256 signature validates against the Google certificate named by the header's `kid`.

Two limits follow from that list.

Verification is **offline**: nothing asks Firebase about the account, so a token stays valid until
its `exp` even if the account was disabled or its refresh tokens were revoked in the meantime. Where
that matters, check the account state yourself.

And **emulator mode skips all four steps**. A configuration built with
``AuthConfiguration/emulator(projectId:host:port:timeout:)`` decodes the token and requires only a
non-empty `sub` — no algorithm check, no `aud` or `iss` check, no expiry check, no signature. That
is what lets the emulator's unsigned tokens through, and it is also why the emulator configuration
must never reach production.

### Key fetching and caching

``PublicKeyCache`` is an actor holding `kid` → PEM certificate. It honours the `Cache-Control`
`max-age` returned by Google's certificate endpoint and falls back to one hour when that header is
absent. A `kid` that is not in the cache triggers a refresh before the lookup is allowed to fail
with ``AuthError/publicKeyNotFound(kid:)``, so Google's routine key rotation resolves itself.

### Getting started

The usual shape is one long-lived ``AuthClient`` per process, used from whatever your framework
calls middleware.

```swift
import FirebaseAuthServer

// Production. Keep one client for the process: the certificate cache lives inside it.
let authClient = AuthClient(projectId: "my-project")

// Running against the Auth emulator instead.
let localClient = AuthClient(
    configuration: .emulator(projectId: "demo-project", port: 9099)
)

// Sharing one HTTP connection pool with the Firestore and Storage clients.
let sharedClient = AuthClient(
    configuration: AuthConfiguration(projectId: "my-project", timeout: 10),
    httpClientProvider: httpClientProvider
)
```

Pass the `Authorization` header straight in — ``AuthClient/verifyAuthorizationHeader(_:)`` strips
the `Bearer ` prefix, matching the scheme case-insensitively, before verifying:

```swift
func authenticate(authorizationHeader: String?) async -> VerifiedToken? {
    do {
        let token = try await authClient.verifyAuthorizationHeader(authorizationHeader ?? "")
        return token
    } catch let error as AuthError {
        switch error {
        case .tokenMissing, .tokenInvalid:
            // No credentials, or not a `Bearer <token>` header. Ask for sign-in.
            return nil

        case .tokenExpired(let expiredAt):
            // The client should refresh and retry; this is not an attack.
            logger.info("token expired at \(expiredAt)")
            return nil

        case .invalidAudience, .invalidIssuer, .signatureInvalid, .unsupportedAlgorithm:
            // A well-formed token from somewhere else. Worth alerting on.
            logger.warning("rejected token: \(error.description) [\(error.errorCode)]")
            return nil

        case .publicKeyFetchFailed, .publicKeyNotFound, .invalidPublicKey:
            // Google's certificate endpoint is the problem, not the caller.
            logger.error("key material unavailable: \(error.description)")
            return nil

        default:
            return nil
        }
    } catch {
        return nil
    }
}
```

What comes back is a ``VerifiedToken``: `uid` plus the profile claims that were present in the
token, and ``VerifiedToken/firebaseClaims`` for the `firebase` claim itself — the sign-in provider
and identities behind it.

```swift
guard let token = await authenticate(authorizationHeader: request.headers["Authorization"]) else {
    return .unauthorized
}

// `uid` is the only claim guaranteed to be present; it is what you key your own
// records on. Everything else depends on the sign-in method.
let userId = token.uid

// Gate on a verified email rather than on the address alone.
guard token.emailVerified else {
    return .forbidden
}

// "password", "google.com", "apple.com", …
logger.info("\(userId) signed in with \(token.signInProvider ?? "unknown")")
```

### Deleting accounts

``AuthAdminClient`` is separate because it needs service-account credentials rather than a caller's
token; it reads them from the Cloud Run metadata server or from local `gcloud`. Deletion is
idempotent — a UID that no longer exists reports success — and it removes only the Auth account, so
any Firestore documents or Storage objects belonging to that user are yours to clean up.

```swift
let admin = AuthAdminClient(projectId: "my-project")

// Against the emulator instead:
// let admin = AuthAdminClient.emulator(projectId: "demo-project")

try await admin.deleteUser(uid: userId)
// The account is gone; the user's own documents and files are not.
try await deleteOwnedData(for: userId)
```

## Topics

### Verifying tokens

- ``AuthClient``
- ``AuthConfiguration``
- ``VerifiedToken``
- ``FirebaseClaim``

### Customizing verification

- ``IDTokenVerifier``
- ``IDTokenVerifying``
- ``PublicKeyCache``

### Managing accounts

- ``AuthAdminClient``

### Errors

- ``AuthError``
