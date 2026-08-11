import Foundation

/// A reference to a document field, used as the left-hand side of a filter condition.
///
/// The operators and methods below build Firestore `fieldFilter` / `unaryFilter` clauses.
/// The examples show the operators in isolation: a real `filter { }` block accepts exactly one
/// top-level filter, so combine several of them with `And { }` or `Or { }`.
///
/// ## Examples
///
/// ```swift
/// // Basic comparisons
/// query.filter {
///     Field("status") == "active"
///     Field("age") >= 18
///     Field("price") < 100.0
/// }
///
/// // Array and null tests
/// query.filter {
///     Field("tags").contains("swift")
///     Field("role").in(["admin", "moderator"])
///     Field("deletedAt").isNull
/// }
/// ```
public struct Field: Sendable {
    public let path: String

    /// Creates a reference to the field at the given path.
    /// - Parameter path: Field path, with nested fields separated by `.`. The path is sent to
    ///   Firestore verbatim, so a segment that is not a plain identifier has to be
    ///   backtick-quoted by the caller.
    public init(_ path: String) {
        self.path = path
    }
}

// MARK: - Comparison Operators

/// Builds an `EQUAL` field filter.
public func == <V: FirestoreValueConvertible>(lhs: Field, rhs: V) -> FieldFilter {
    FieldFilter(
        field: FieldReference(lhs.path),
        op: .equal,
        value: rhs.toFirestoreValue()
    )
}

/// Builds a `NOT_EQUAL` field filter.
///
/// Firestore does not return documents that lack the field, and it orders the results by this
/// field, so any other sort key has to come after it.
public func != <V: FirestoreValueConvertible>(lhs: Field, rhs: V) -> FieldFilter {
    FieldFilter(
        field: FieldReference(lhs.path),
        op: .notEqual,
        value: rhs.toFirestoreValue()
    )
}

/// Builds a `LESS_THAN` field filter.
///
/// Firestore requires the first `order(by:)` of a query to name the same field as its range
/// filter, and a range filter combined with any other clause needs a composite index.
public func < <V: FirestoreValueConvertible>(lhs: Field, rhs: V) -> FieldFilter {
    FieldFilter(
        field: FieldReference(lhs.path),
        op: .lessThan,
        value: rhs.toFirestoreValue()
    )
}

/// Builds a `LESS_THAN_OR_EQUAL` field filter.
///
/// Firestore requires the first `order(by:)` of a query to name the same field as its range
/// filter.
public func <= <V: FirestoreValueConvertible>(lhs: Field, rhs: V) -> FieldFilter {
    FieldFilter(
        field: FieldReference(lhs.path),
        op: .lessThanOrEqual,
        value: rhs.toFirestoreValue()
    )
}

/// Builds a `GREATER_THAN` field filter.
///
/// Firestore requires the first `order(by:)` of a query to name the same field as its range
/// filter.
public func > <V: FirestoreValueConvertible>(lhs: Field, rhs: V) -> FieldFilter {
    FieldFilter(
        field: FieldReference(lhs.path),
        op: .greaterThan,
        value: rhs.toFirestoreValue()
    )
}

/// Builds a `GREATER_THAN_OR_EQUAL` field filter.
///
/// Firestore requires the first `order(by:)` of a query to name the same field as its range
/// filter.
public func >= <V: FirestoreValueConvertible>(lhs: Field, rhs: V) -> FieldFilter {
    FieldFilter(
        field: FieldReference(lhs.path),
        op: .greaterThanOrEqual,
        value: rhs.toFirestoreValue()
    )
}

// MARK: - Array & Special Operations

extension Field {
    /// Matches documents whose array field contains the given element.
    ///
    /// Builds an `ARRAY_CONTAINS` filter. Firestore allows only one `array-contains` clause per
    /// query and refuses to combine it with `containsAny(_:)`.
    ///
    /// ```swift
    /// Field("tags").contains("swift")
    /// ```
    public func contains<V: FirestoreValueConvertible>(_ value: V) -> FieldFilter {
        FieldFilter(
            field: FieldReference(path),
            op: .arrayContains,
            value: value.toFirestoreValue()
        )
    }

    /// Matches documents whose array field contains at least one of the given elements.
    ///
    /// Builds an `ARRAY_CONTAINS_ANY` filter whose operand is an `arrayValue`. Firestore treats
    /// each element as a separate disjunction, caps the list at 30 values, allows one such
    /// clause per query, and refuses to combine it with `contains(_:)`.
    ///
    /// ```swift
    /// Field("tags").containsAny(["swift", "ios", "macos"])
    /// ```
    public func containsAny<V: FirestoreValueConvertible>(_ values: [V]) -> FieldFilter {
        FieldFilter(
            field: FieldReference(path),
            op: .arrayContainsAny,
            value: .array(values.map { $0.toFirestoreValue() })
        )
    }

    /// Matches documents whose field equals any of the given values.
    ///
    /// Builds an `IN` filter whose operand is an `arrayValue`. Firestore treats each element as
    /// a separate disjunction and caps the list at 30 values; nothing here checks the count, so
    /// a longer list is rejected by the server.
    ///
    /// ```swift
    /// Field("status").in(["active", "pending"])
    /// ```
    public func `in`<V: FirestoreValueConvertible>(_ values: [V]) -> FieldFilter {
        FieldFilter(
            field: FieldReference(path),
            op: .in,
            value: .array(values.map { $0.toFirestoreValue() })
        )
    }

    /// Matches documents whose field equals none of the given values.
    ///
    /// Builds a `NOT_IN` filter whose operand is an `arrayValue`. Firestore caps the operand
    /// list, excludes documents that lack the field, and refuses to combine `not-in` with
    /// `in`, `array-contains-any`, or `!=`.
    ///
    /// ```swift
    /// Field("status").notIn(["deleted", "archived"])
    /// ```
    public func notIn<V: FirestoreValueConvertible>(_ values: [V]) -> FieldFilter {
        FieldFilter(
            field: FieldReference(path),
            op: .notIn,
            value: .array(values.map { $0.toFirestoreValue() })
        )
    }

    /// Matches documents whose field is explicitly null.
    ///
    /// Builds an `IS_NULL` unary filter, which takes no operand. A document that omits the
    /// field entirely does not match.
    ///
    /// ```swift
    /// Field("deletedAt").isNull
    /// ```
    public var isNull: UnaryFilter {
        UnaryFilter(
            field: FieldReference(path),
            op: .isNull
        )
    }

    /// Matches documents whose field is present and not null.
    ///
    /// Builds an `IS_NOT_NULL` unary filter, which takes no operand.
    ///
    /// ```swift
    /// Field("email").isNotNull
    /// ```
    public var isNotNull: UnaryFilter {
        UnaryFilter(
            field: FieldReference(path),
            op: .isNotNull
        )
    }

    /// Matches documents whose field holds the double NaN.
    ///
    /// Builds an `IS_NAN` unary filter. NaN is the one double that no equality or range filter
    /// can reach, which is why it needs its own operator.
    ///
    /// ```swift
    /// Field("score").isNaN
    /// ```
    public var isNaN: UnaryFilter {
        UnaryFilter(
            field: FieldReference(path),
            op: .isNaN
        )
    }

    /// Matches documents whose field is present and is not the double NaN.
    ///
    /// Builds an `IS_NOT_NAN` unary filter, which takes no operand.
    ///
    /// ```swift
    /// Field("score").isNotNaN
    /// ```
    public var isNotNaN: UnaryFilter {
        UnaryFilter(
            field: FieldReference(path),
            op: .isNotNaN
        )
    }
}
