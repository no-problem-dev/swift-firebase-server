import Foundation

// MARK: - Field Reference

/// A reference to a document field, as used by filters, sort keys, and projections.
public struct FieldReference: Sendable, Hashable {
    /// The path, with nested fields separated by `.`. It is sent verbatim, so a segment that is
    /// not a plain identifier has to be backtick-quoted by the caller.
    public let fieldPath: String

    public init(_ fieldPath: String) {
        self.fieldPath = fieldPath
    }

    /// The `__name__` pseudo-field holding the document's identity.
    ///
    /// Firestore compares it against the document's full resource name — a `referenceValue`
    /// such as `projects/p/databases/(default)/documents/users/abc`, not the bare ID — and
    /// appends it to every query as the final sort key.
    public static let documentId = FieldReference("__name__")

    func toJSON() -> [String: Any] {
        ["fieldPath": fieldPath]
    }
}

// MARK: - Sort Direction

/// Direction of an `orderBy` entry, whose raw values are the REST enum names.
public enum SortDirection: String, Sendable, Hashable {
    case ascending = "ASCENDING"
    case descending = "DESCENDING"
}

// MARK: - Order

/// One `orderBy` entry of a query.
///
/// A query that carries a range filter has to name that filter's field first, and Firestore
/// appends `__name__` after whatever entries are given.
public struct QueryOrder: Sendable, Hashable {
    public let field: FieldReference
    public let direction: SortDirection

    public init(field: FieldReference, direction: SortDirection = .ascending) {
        self.field = field
        self.direction = direction
    }

    public init(_ fieldPath: String, direction: SortDirection = .ascending) {
        self.field = FieldReference(fieldPath)
        self.direction = direction
    }

    func toJSON() -> [String: Any] {
        [
            "field": field.toJSON(),
            "direction": direction.rawValue,
        ]
    }
}

// MARK: - Cursor

/// A `startAt` or `endAt` bound, given as values matching the query's sort keys.
///
/// The values are positional: they line up with the `orderBy` entries in order, and there may
/// not be more of them than there are sort keys. `before` says whether the boundary sits just
/// before or just after those values, which means it reads differently at each end — `true` is
/// inclusive for a start bound and exclusive for an end bound.
public struct QueryCursor: Sendable, Hashable {
    public let values: [FirestoreValue]
    public let before: Bool

    /// Places the boundary just after the given values.
    ///
    /// That is inclusive when used as an `endAt` bound and exclusive when used as a `startAt`
    /// bound.
    public static func at(_ values: FirestoreValue...) -> QueryCursor {
        QueryCursor(values: values, before: false)
    }

    /// Places the boundary just before the given values.
    ///
    /// That is inclusive when used as a `startAt` bound and exclusive when used as an `endAt`
    /// bound.
    public static func before(_ values: FirestoreValue...) -> QueryCursor {
        QueryCursor(values: values, before: true)
    }

    func toJSON() -> [String: Any] {
        [
            "values": values.map { $0.toJSON() },
            "before": before,
        ]
    }
}

// MARK: - Projection

/// A `select` clause naming the only fields the query should return.
///
/// Every other field is left out of the returned documents. A projection of just `__name__`
/// makes the query keys-only, which reads no document content.
public struct QueryProjection: Sendable, Hashable {
    public let fields: [FieldReference]

    public init(fields: [FieldReference]) {
        self.fields = fields
    }

    public init(_ fieldPaths: String...) {
        self.fields = fieldPaths.map { FieldReference($0) }
    }

    public init(fieldPaths: [String]) {
        self.fields = fieldPaths.map { FieldReference($0) }
    }

    func toJSON() -> [String: Any] {
        ["fields": fields.map { $0.toJSON() }]
    }
}

// MARK: - Collection Selector

/// A `from` entry naming the collection a query reads.
///
/// With `allDescendants` set the query becomes a collection group query, covering every
/// collection with this ID at any depth below the parent rather than the one child collection.
public struct CollectionSelector: Sendable, Hashable {
    public let collectionId: String
    public let allDescendants: Bool

    public init(collectionId: String, allDescendants: Bool = false) {
        self.collectionId = collectionId
        self.allDescendants = allDescendants
    }

    func toJSON() -> [String: Any] {
        [
            "collectionId": collectionId,
            "allDescendants": allDescendants,
        ]
    }
}
