# ``EventarcServer``

CloudEvents payloads delivered by Google Cloud Eventarc, as Swift types.

## Overview

Eventarc pushes an event to your service as an ordinary HTTP request: the CloudEvents attributes
arrive as `ce-*` headers and the payload arrives in the body. This module gives you a reader for
those headers and a decoded Swift value for each payload shape the package supports. It does no
networking of its own — you hand it the bytes your web framework already collected.

| Event source | Payload type | Body encoding |
| --- | --- | --- |
| Firestore document changes | ``FirestoreDocumentEvent`` | Protobuf, via ``FirestoreProtobufDecoder`` |
| Cloud Audit Logs, including Identity Platform sign-up and account deletion | ``CloudAuditLogEvent`` | JSON |
| Firebase Auth user creation | ``AuthUserCreatedEvent`` | JSON |

Two things about the payloads are worth knowing before you write a handler:

- **Firestore triggers emit `application/protobuf` only.** There is no JSON encoding to fall back
  on, so a Firestore body has to go through ``FirestoreProtobufDecoder`` rather than
  `JSONDecoder`. The decoder converts the generated Protobuf message into the same
  ``FirestoreDocumentEvent`` shape the JSON-based events use.
- **Audit log payloads carry the audited call's own request and response as
  `google.protobuf.Struct`.** That has no fixed Swift shape, so it decodes to ``DynamicValue`` and
  is read by key. ``CloudAuditLogEvent`` wraps the common Identity Platform lookups —
  `isIdentityPlatformSignUp`, `signedUpUserId`, `signedUpUserEmail` — so you rarely have to walk
  it yourself.

``CloudEventHeaders`` reads the `ce-*` keys verbatim from the dictionary you pass, so give it
headers keyed by lowercased name. The event type strings are available as constants on it —
`CloudEventHeaders.FirestoreEventType`, `.AuthEventType`, and `.AuditLogEventType` — which keeps
the trigger names out of your source as string literals.

### Getting started

A single Cloud Run endpoint can serve several triggers. Read the type from the headers first,
then decode the body with the decoder that trigger uses.

```swift
import EventarcServer
import Foundation

/// Handles one Eventarc delivery.
/// - Parameters:
///   - headers: The request headers, keyed by lowercased header name.
///   - body: The collected request body.
func handleEventarcDelivery(headers: [String: String], body: Data) throws {
    let cloudEvent = CloudEventHeaders(from: headers)

    guard let type = cloudEvent.type else {
        // No `ce-type` header: either not a CloudEvents request, or the header
        // dictionary was not lowercased before it got here.
        return
    }

    switch type {
    case CloudEventHeaders.FirestoreEventType.documentCreated:
        // Firestore delivers Protobuf, never JSON.
        let change = try FirestoreProtobufDecoder.decode(body)

        // The document path is only in the payload, not in a route parameter.
        if let params = change.extractPathParams(
            pattern: "users/{userId}/books/{bookId}/chats/{chatId}"
        ),
           let bookId = params["bookId"],
           let message = change.value?.getString("message") {
            print("new chat in book \(bookId): \(message)")
        }

    case CloudEventHeaders.FirestoreEventType.documentUpdated:
        let change = try FirestoreProtobufDecoder.decode(body)

        // `updateMask` names the fields that actually changed; `oldValue` holds
        // the document as it was before the write.
        for path in change.updateMask?.fieldPaths ?? [] {
            let before = change.oldValue?.getString(path)
            let after = change.value?.getString(path)
            print("\(path): \(before ?? "nil") -> \(after ?? "nil")")
        }

    case CloudEventHeaders.AuditLogEventType.logWritten:
        let entry = try JSONDecoder().decode(CloudAuditLogEvent.self, from: body)

        if let uid = entry.signedUpUserId {
            print("signed up: \(uid) <\(entry.signedUpUserEmail ?? "no email")>")
        } else if entry.isIdentityPlatformDeleteAccount {
            print("account deleted: \(entry.protoPayload?.resourceName ?? "unknown")")
        }

    default:
        break
    }
}
```

### Creating the triggers

The payload type follows from how the trigger is filtered, so the two have to be decided
together. A Firestore trigger has to declare the Protobuf content type explicitly:

```bash
gcloud eventarc triggers create firestore-chat-created \
  --location=asia-northeast1 \
  --destination-run-service=your-service \
  --destination-run-region=asia-northeast1 \
  --destination-run-path="/webhooks/eventarc" \
  --event-filters="type=google.cloud.firestore.document.v1.created" \
  --event-filters="database=(default)" \
  --event-filters-path-pattern="document=users/*/books/*/chats/*" \
  --event-data-content-type="application/protobuf" \
  --service-account="PROJECT_NUMBER-compute@developer.gserviceaccount.com"
```

Firebase Auth is not an Eventarc provider, so sign-ups are reached through the audit log for
Identity Platform instead:

```bash
gcloud eventarc triggers create auth-user-signup \
  --location=asia-northeast1 \
  --destination-run-service=your-service \
  --destination-run-region=asia-northeast1 \
  --destination-run-path="/webhooks/eventarc" \
  --event-filters="type=google.cloud.audit.log.v1.written" \
  --event-filters="serviceName=identitytoolkit.googleapis.com" \
  --event-filters="methodName=google.cloud.identitytoolkit.v1.AuthenticationService.SignUp" \
  --service-account="PROJECT_NUMBER-compute@developer.gserviceaccount.com"
```

## Topics

### CloudEvents metadata

- ``CloudEventHeaders``

### Firestore document events

- ``FirestoreDocumentEvent``
- ``FirestoreProtobufDecoder``
- ``FirestoreDocument``
- ``FirestoreValue``

### Cloud Audit Logs events

- ``CloudAuditLogEvent``
- ``DynamicValue``
- ``JSONValue``

### Firebase Auth events

- ``AuthUserCreatedEvent``

### Generated Protobuf messages

Generated from the `google-cloudevents` protos. ``FirestoreProtobufDecoder`` converts these into
``FirestoreDocumentEvent``; reach for them directly only when you need a field the conversion
does not carry across.

- ``Google_Events_Cloud_Firestore_V1_DocumentEventData``
- ``Google_Events_Cloud_Firestore_V1_Document``
- ``Google_Events_Cloud_Firestore_V1_DocumentMask``
- ``Google_Events_Cloud_Firestore_V1_Value``
- ``Google_Events_Cloud_Firestore_V1_ArrayValue``
- ``Google_Events_Cloud_Firestore_V1_MapValue``
- ``Google_Type_LatLng``
