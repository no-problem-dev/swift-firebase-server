import Foundation

/// The payload of a Firestore document change delivered by Eventarc.
///
/// Eventarc triggers:
/// - `google.cloud.firestore.document.v1.created`
/// - `google.cloud.firestore.document.v1.updated`
/// - `google.cloud.firestore.document.v1.deleted`
/// - `google.cloud.firestore.document.v1.written`
///
/// Which of the three fields are populated is what tells the kinds of change apart, and it is
/// the only way to tell under the `written` trigger, which fires for all three:
///
/// | Change | `value` | `oldValue` | `updateMask` |
/// | --- | --- | --- | --- |
/// | create | set | `nil` | `nil` |
/// | update | set | set | set |
/// | delete | `nil` | set | `nil` |
///
/// - Important: Firestore triggers deliver `application/protobuf` only; there is no JSON
///   delivery. Decode the request body with `FirestoreProtobufDecoder`, which is what produces
///   instances of this type. The `Codable` conformance is for your own storage and fixtures.
///
/// ## Example
/// ```swift
/// server.webhook("webhooks", "firestore", "chat-created", body: FirestoreDocumentEvent.self) { request in
///     let event = request.body
///     if let message = event.value?.getString("message") {
///         print("New chat: \(message)")
///     }
///     return .ok
/// }
/// ```
public struct FirestoreDocumentEvent: Codable, Sendable {
    /// The document as it stands after the change, or `nil` for a delete.
    public let value: FirestoreDocument?

    /// The document as it stood before the change, populated for updates and deletes and `nil`
    /// for a create.
    ///
    /// For a delete this is the only copy of the document you get.
    public let oldValue: FirestoreDocument?

    /// The fields that changed, populated for updates only.
    ///
    /// Its presence is the cheapest way to recognise an update under the `written` trigger.
    public let updateMask: UpdateMask?

    /// The set of fields an update touched.
    public struct UpdateMask: Codable, Sendable {
        /// The paths of the changed fields, using `.` to descend into maps, as in `owner.name`.
        ///
        /// `nil` rather than empty when the event carried no paths.
        public let fieldPaths: [String]?

        public init(fieldPaths: [String]?) {
            self.fieldPaths = fieldPaths
        }
    }

    /// Creates an event directly, as the protobuf decoder does and as tests do.
    public init(value: FirestoreDocument?, oldValue: FirestoreDocument?, updateMask: UpdateMask?) {
        self.value = value
        self.oldValue = oldValue
        self.updateMask = updateMask
    }
}

// MARK: - Firestore Document

/// A document snapshot in Firestore's own wire representation.
///
/// Fields keep their type wrapper rather than being flattened into Swift values, so reach them
/// through the typed getters below instead of touching `fields` directly.
public struct FirestoreDocument: Codable, Sendable {
    /// The document's full resource name, for example
    /// `projects/my-project/databases/(default)/documents/users/abc123/books/xyz789`.
    ///
    /// The protobuf decoder always sets this, using an empty string when the message omitted it,
    /// so treat empty the way you would treat `nil`.
    public let name: String?

    /// The document's top-level fields, each still wrapped in its Firestore type.
    ///
    /// Reserved names matching `__.*__` never appear, and a field name is at most 1,500 bytes
    /// of UTF-8.
    public let fields: [String: FirestoreValue]?

    /// When the document was created, as an ISO 8601 timestamp with fractional seconds.
    ///
    /// It increases monotonically when a document is deleted and recreated, so it is not stable
    /// across a delete.
    public let createTime: String?

    /// When the document last changed, as an ISO 8601 timestamp with fractional seconds.
    ///
    /// It starts equal to `createTime` and increases with every change, which makes it usable
    /// for ordering two deliveries for the same document.
    public let updateTime: String?

    /// Creates a snapshot directly, as the protobuf decoder does and as tests do.
    public init(
        name: String?,
        fields: [String: FirestoreValue]?,
        createTime: String?,
        updateTime: String?
    ) {
        self.name = name
        self.fields = fields
        self.createTime = createTime
        self.updateTime = updateTime
    }

    /// The document's own ID, the last segment of its resource name.
    ///
    /// `nil` only when `name` is `nil`; the path is not validated, so whatever follows the last
    /// slash is returned.
    public var documentId: String? {
        guard let name = name else { return nil }
        return name.split(separator: "/").last.map(String.init)
    }

    /// Returns a top-level string field, or `nil` when the field is absent or holds another
    /// type. Nothing is coerced.
    public func getString(_ key: String) -> String? {
        fields?[key]?.stringValue
    }

    /// Returns a top-level integer field, parsing the decimal string Firestore transmits.
    ///
    /// `nil` when the field is absent, holds another type, or names a 64-bit value too large for
    /// `Int` on this platform.
    public func getInt(_ key: String) -> Int? {
        guard let value = fields?[key]?.integerValue else { return nil }
        return Int(value)
    }

    /// Returns a top-level boolean field, or `nil` when the field is absent or holds another
    /// type.
    public func getBool(_ key: String) -> Bool? {
        fields?[key]?.booleanValue
    }

    /// Returns a top-level double field, or `nil` when the field is absent or holds another
    /// type. A field Firestore stored as an integer does not come back here — use `getInt(_:)`.
    public func getDouble(_ key: String) -> Double? {
        fields?[key]?.doubleValue
    }

    /// Returns a top-level timestamp field as its ISO 8601 string, or `nil` when the field is
    /// absent or holds another type.
    public func getTimestamp(_ key: String) -> String? {
        fields?[key]?.timestampValue
    }

    /// Returns the fields of a top-level map field, still in their Firestore wrappers.
    ///
    /// Only one level deep: read a nested map from the returned dictionary yourself.
    public func getMap(_ key: String) -> [String: FirestoreValue]? {
        fields?[key]?.mapValue?.fields
    }

    /// Returns the elements of a top-level array field, still in their Firestore wrappers.
    ///
    /// Elements need not share a type, so unwrap each one on its own.
    public func getArray(_ key: String) -> [FirestoreValue]? {
        fields?[key]?.arrayValue?.values
    }
}

// MARK: - Firestore Value

/// One field value in Firestore's typed wire representation.
///
/// Firestore tags every value with its type instead of writing a bare JSON value, so this is a
/// tagged union spelled as a struct: exactly one property is non-`nil`, and which one tells you
/// the field's Firestore type. Read the one you expect and treat `nil` as "the field is not that
/// type", never as "the field is empty".
public struct FirestoreValue: Codable, Sendable {
    public let stringValue: String?

    /// A 64-bit integer, transmitted as a decimal string so that large values survive JSON.
    public let integerValue: String?

    public let booleanValue: Bool?

    public let doubleValue: Double?

    /// A timestamp, as an ISO 8601 string with fractional seconds when it came from the protobuf
    /// decoder.
    public let timestampValue: String?

    /// Set when the field holds an explicit null. The string itself carries no information — the
    /// protobuf decoder writes `"NULL_VALUE"` — so test only for presence.
    public let nullValue: String?

    /// A nested object, which can itself contain maps and arrays.
    public let mapValue: MapValue?

    /// An array, whose elements need not share a type.
    public let arrayValue: ArrayValue?

    /// A reference to another document, as that document's full resource name.
    public let referenceValue: String?

    public let geoPointValue: GeoPointValue?

    /// A blob, Base64-encoded.
    public let bytesValue: String?

    /// The contents of a map value.
    public struct MapValue: Codable, Sendable {
        public let fields: [String: FirestoreValue]?

        public init(fields: [String: FirestoreValue]?) {
            self.fields = fields
        }
    }

    /// The contents of an array value.
    public struct ArrayValue: Codable, Sendable {
        public let values: [FirestoreValue]?

        public init(values: [FirestoreValue]?) {
            self.values = values
        }
    }

    /// A geographical point, in degrees.
    public struct GeoPointValue: Codable, Sendable {
        public let latitude: Double?
        public let longitude: Double?

        public init(latitude: Double?, longitude: Double?) {
            self.latitude = latitude
            self.longitude = longitude
        }
    }

    // MARK: - Initializers

    /// Creates a value with no type set, which is what a protobuf value whose type is unset or
    /// unrecognised decodes to. Every accessor on it is `nil`.
    public init() {
        self.stringValue = nil
        self.integerValue = nil
        self.booleanValue = nil
        self.doubleValue = nil
        self.timestampValue = nil
        self.nullValue = nil
        self.mapValue = nil
        self.arrayValue = nil
        self.referenceValue = nil
        self.geoPointValue = nil
        self.bytesValue = nil
    }

    public init(stringValue: String) {
        self.stringValue = stringValue
        self.integerValue = nil
        self.booleanValue = nil
        self.doubleValue = nil
        self.timestampValue = nil
        self.nullValue = nil
        self.mapValue = nil
        self.arrayValue = nil
        self.referenceValue = nil
        self.geoPointValue = nil
        self.bytesValue = nil
    }

    /// Creates an integer value from its decimal string form, which is how Firestore transmits
    /// 64-bit integers.
    public init(integerValue: String) {
        self.stringValue = nil
        self.integerValue = integerValue
        self.booleanValue = nil
        self.doubleValue = nil
        self.timestampValue = nil
        self.nullValue = nil
        self.mapValue = nil
        self.arrayValue = nil
        self.referenceValue = nil
        self.geoPointValue = nil
        self.bytesValue = nil
    }

    public init(booleanValue: Bool) {
        self.stringValue = nil
        self.integerValue = nil
        self.booleanValue = booleanValue
        self.doubleValue = nil
        self.timestampValue = nil
        self.nullValue = nil
        self.mapValue = nil
        self.arrayValue = nil
        self.referenceValue = nil
        self.geoPointValue = nil
        self.bytesValue = nil
    }

    public init(doubleValue: Double) {
        self.stringValue = nil
        self.integerValue = nil
        self.booleanValue = nil
        self.doubleValue = doubleValue
        self.timestampValue = nil
        self.nullValue = nil
        self.mapValue = nil
        self.arrayValue = nil
        self.referenceValue = nil
        self.geoPointValue = nil
        self.bytesValue = nil
    }

    /// Creates a timestamp value from its string form; callers pass ISO 8601 with fractional
    /// seconds, matching what the protobuf decoder produces.
    public init(timestampValue: String) {
        self.stringValue = nil
        self.integerValue = nil
        self.booleanValue = nil
        self.doubleValue = nil
        self.timestampValue = timestampValue
        self.nullValue = nil
        self.mapValue = nil
        self.arrayValue = nil
        self.referenceValue = nil
        self.geoPointValue = nil
        self.bytesValue = nil
    }

    /// Creates an explicit null value. The string is a placeholder that is never interpreted;
    /// the protobuf decoder passes `"NULL_VALUE"`.
    public init(nullValue: String) {
        self.stringValue = nil
        self.integerValue = nil
        self.booleanValue = nil
        self.doubleValue = nil
        self.timestampValue = nil
        self.nullValue = nullValue
        self.mapValue = nil
        self.arrayValue = nil
        self.referenceValue = nil
        self.geoPointValue = nil
        self.bytesValue = nil
    }

    public init(mapValue: MapValue) {
        self.stringValue = nil
        self.integerValue = nil
        self.booleanValue = nil
        self.doubleValue = nil
        self.timestampValue = nil
        self.nullValue = nil
        self.mapValue = mapValue
        self.arrayValue = nil
        self.referenceValue = nil
        self.geoPointValue = nil
        self.bytesValue = nil
    }

    public init(arrayValue: ArrayValue) {
        self.stringValue = nil
        self.integerValue = nil
        self.booleanValue = nil
        self.doubleValue = nil
        self.timestampValue = nil
        self.nullValue = nil
        self.mapValue = nil
        self.arrayValue = arrayValue
        self.referenceValue = nil
        self.geoPointValue = nil
        self.bytesValue = nil
    }

    /// Creates a document reference from the referenced document's full resource name.
    public init(referenceValue: String) {
        self.stringValue = nil
        self.integerValue = nil
        self.booleanValue = nil
        self.doubleValue = nil
        self.timestampValue = nil
        self.nullValue = nil
        self.mapValue = nil
        self.arrayValue = nil
        self.referenceValue = referenceValue
        self.geoPointValue = nil
        self.bytesValue = nil
    }

    public init(geoPointValue: GeoPointValue) {
        self.stringValue = nil
        self.integerValue = nil
        self.booleanValue = nil
        self.doubleValue = nil
        self.timestampValue = nil
        self.nullValue = nil
        self.mapValue = nil
        self.arrayValue = nil
        self.referenceValue = nil
        self.geoPointValue = geoPointValue
        self.bytesValue = nil
    }

    /// Creates a blob value from its Base64 encoding; the bytes are not decoded or validated.
    public init(bytesValue: String) {
        self.stringValue = nil
        self.integerValue = nil
        self.booleanValue = nil
        self.doubleValue = nil
        self.timestampValue = nil
        self.nullValue = nil
        self.mapValue = nil
        self.arrayValue = nil
        self.referenceValue = nil
        self.geoPointValue = nil
        self.bytesValue = bytesValue
    }
}

// MARK: - Path Parameter Extraction

extension FirestoreDocumentEvent {
    /// Matches the changed document's path against a pattern and returns the named segments.
    ///
    /// The path is taken from `value` and falls back to `oldValue`, so this works for deletes as
    /// well as creates and updates. Matching is exact and segment-by-segment: the pattern must
    /// have the same number of segments as the document path, literal segments must be equal,
    /// and `{name}` captures whatever segment sits in its place. There is no wildcard and no
    /// prefix matching, so the `*` you write in an Eventarc `--event-filters-path-pattern` must
    /// be rewritten as `{name}` here; a `*` would be compared literally and never match.
    ///
    /// ## Example
    /// ```swift
    /// let event: FirestoreDocumentEvent = ...
    /// let params = event.extractPathParams(pattern: "users/{userId}/books/{bookId}/chats/{chatId}")
    /// // params = ["userId": "abc123", "bookId": "xyz789", "chatId": "chat001"]
    /// ```
    ///
    /// - Parameter pattern: The path below `documents/`, with `{name}` placeholders for the
    ///   segments to capture. No leading slash.
    /// - Returns: The captured segments, empty when the pattern has no placeholders, or `nil`
    ///   when the event carries no document name, the name has no `/documents/` part, the
    ///   segment counts differ, or a literal segment does not match.
    public func extractPathParams(pattern: String) -> [String: String]? {
        guard let name = value?.name ?? oldValue?.name else { return nil }

        // Cut the document path out of the full resource name
        // Shape: projects/{project}/databases/(default)/documents/{path}
        guard let documentsIndex = name.range(of: "/documents/") else { return nil }
        let documentPath = String(name[documentsIndex.upperBound...])

        let patternParts = pattern.split(separator: "/")
        let pathParts = documentPath.split(separator: "/")

        guard patternParts.count == pathParts.count else { return nil }

        var params: [String: String] = [:]

        for (patternPart, pathPart) in zip(patternParts, pathParts) {
            let pattern = String(patternPart)
            let path = String(pathPart)

            if pattern.hasPrefix("{") && pattern.hasSuffix("}") {
                // A placeholder: capture this segment
                let paramName = String(pattern.dropFirst().dropLast())
                params[paramName] = path
            } else if pattern != path {
                // A literal segment that does not match
                return nil
            }
        }

        return params
    }
}
