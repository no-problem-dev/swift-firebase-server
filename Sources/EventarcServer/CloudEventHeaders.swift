import Foundation

/// The CloudEvents metadata carried in the HTTP headers of an Eventarc delivery.
///
/// Eventarc delivers events in CloudEvents binary content mode: the payload is the HTTP body and
/// the event metadata travels in `ce-*` headers. This type reads only that metadata; decode the
/// body separately, with `FirestoreProtobufDecoder` for Firestore events or with JSON decoding
/// for the Cloud Audit Logs and Firebase Auth payloads.
///
/// Header names are matched in lowercase and the dictionary you pass in is never normalized, so
/// build it from lowercased keys. Every property is `nil` when its header is absent.
///
/// ## CloudEvents headers
/// - `ce-type`: the event type, for example `google.firebase.auth.user.v1.created`
/// - `ce-source`: the emitting resource, for example `//firebaseauth.googleapis.com/projects/my-project`
/// - `ce-id`: the event ID, a UUID
/// - `ce-time`: the time the event occurred, in RFC 3339 format
/// - `ce-subject`: the subject within the source; optional, and Firestore deliveries put the document path here
/// - `ce-specversion`: the CloudEvents spec version, normally `1.0`
///
/// ## References
/// - [CloudEvents Spec](https://cloudevents.io/)
/// - [Eventarc CloudEvents](https://cloud.google.com/eventarc/docs/cloudevents)
public struct CloudEventHeaders: Sendable {
    /// The event type from `ce-type`, which tells you what the body contains.
    ///
    /// Compare it against the constants in `FirestoreEventType`, `AuthEventType`, or
    /// `AuditLogEventType` to pick a decoder.
    public let type: String?

    /// The emitting Google Cloud resource, from `ce-source`.
    public let source: String?

    /// The event ID from `ce-id`.
    ///
    /// Eventarc delivers at least once, so use this as the deduplication key when the same
    /// event arrives twice.
    public let id: String?

    /// The time the event occurred at the source, from `ce-time`, in RFC 3339 format.
    ///
    /// This is the occurrence time, not the time the delivery reached your service, so it can
    /// be well in the past after a retry.
    public let time: String?

    /// The subject of the event within its source, from `ce-subject`.
    ///
    /// The header is optional in CloudEvents. Firestore deliveries carry the changed document's
    /// path here, for example `documents/users/abc123/books/xyz789`.
    public let subject: String?

    /// The CloudEvents spec version from `ce-specversion`, normally `1.0`.
    public let specVersion: String?

    /// The dictionary the instance was built from, kept so the subscript can reach headers
    /// outside the CloudEvents set.
    private let rawHeaders: [String: String]

    /// Creates a CloudEvents view over a request's HTTP headers.
    ///
    /// The `ce-*` keys are read verbatim, without lowercasing the dictionary, so a dictionary
    /// keyed by `Ce-Type` leaves every property `nil`.
    ///
    /// - Parameter headers: The request headers, keyed by lowercased header name.
    public init(from headers: [String: String]) {
        self.rawHeaders = headers
        self.type = headers["ce-type"]
        self.source = headers["ce-source"]
        self.id = headers["ce-id"]
        self.time = headers["ce-time"]
        self.subject = headers["ce-subject"]
        self.specVersion = headers["ce-specversion"]
    }

    /// Returns any header value, lowercasing the name you pass before the lookup.
    ///
    /// Only the name is lowercased; the stored dictionary is used as given, so headers kept
    /// under mixed-case keys are still missed.
    public subscript(_ key: String) -> String? {
        rawHeaders[key.lowercased()]
    }

    /// A multi-line dump of the six CloudEvents fields, showing `nil` for absent headers.
    ///
    /// Only those six are listed; other headers in the dictionary do not appear. The type does
    /// not conform to `CustomDebugStringConvertible`, so read this property directly.
    public var debugDescription: String {
        """
        CloudEventHeaders:
          type: \(type ?? "nil")
          source: \(source ?? "nil")
          id: \(id ?? "nil")
          time: \(time ?? "nil")
          subject: \(subject ?? "nil")
          specVersion: \(specVersion ?? "nil")
        """
    }
}

// MARK: - Firebase Auth Event Types

extension CloudEventHeaders {
    /// The `ce-type` values for Firebase Auth user events.
    ///
    /// - Note: Firebase Auth is not itself an Eventarc provider. Sign-ups and deletions usually
    ///   reach Cloud Run as Cloud Audit Logs entries instead, typed
    ///   `google.cloud.audit.log.v1.written` and decoded as `CloudAuditLogEvent`.
    public enum AuthEventType {
        public static let userCreated = "google.firebase.auth.user.v1.created"
        public static let userDeleted = "google.firebase.auth.user.v1.deleted"
    }
}

// MARK: - Firestore Event Types

extension CloudEventHeaders {
    /// The `ce-type` values for Firestore document events.
    ///
    /// The first three narrow a trigger to one kind of change; `documentWritten` covers all
    /// three at once, so distinguish them from the payload: a create has no `oldValue`, a delete
    /// has no `value`, and only an update carries an `updateMask`.
    public enum FirestoreEventType {
        public static let documentCreated = "google.cloud.firestore.document.v1.created"
        public static let documentUpdated = "google.cloud.firestore.document.v1.updated"
        public static let documentDeleted = "google.cloud.firestore.document.v1.deleted"
        /// Any create, update, or delete of a matching document.
        public static let documentWritten = "google.cloud.firestore.document.v1.written"
    }
}
