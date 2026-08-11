import Foundation

// MARK: - Query Filter Protocol

/// A clause of a Firestore `structuredQuery.where`.
public protocol QueryFilterProtocol: Sendable, Hashable {
    /// Renders the clause as a REST `Filter` object, keyed by `fieldFilter`, `unaryFilter`, or
    /// `compositeFilter`.
    func toJSON() -> [String: Any]
}

// MARK: - Field Filter Operator

/// Comparison operators of a Firestore `fieldFilter`, whose raw values are the REST enum names.
public enum FieldFilterOperator: String, Sendable, Hashable {
    case lessThan = "LESS_THAN"
    case lessThanOrEqual = "LESS_THAN_OR_EQUAL"
    case greaterThan = "GREATER_THAN"
    case greaterThanOrEqual = "GREATER_THAN_OR_EQUAL"
    case equal = "EQUAL"
    case notEqual = "NOT_EQUAL"
    case arrayContains = "ARRAY_CONTAINS"
    case `in` = "IN"
    case arrayContainsAny = "ARRAY_CONTAINS_ANY"
    case notIn = "NOT_IN"
}

// MARK: - Unary Filter Operator

/// Operators of a Firestore `unaryFilter`, which tests a field without an operand.
public enum UnaryFilterOperator: String, Sendable, Hashable {
    case isNaN = "IS_NAN"
    case isNull = "IS_NULL"
    case isNotNaN = "IS_NOT_NAN"
    case isNotNull = "IS_NOT_NULL"
}

// MARK: - Composite Filter Operator

/// Operators of a Firestore `compositeFilter`.
public enum CompositeFilterOperator: String, Sendable, Hashable {
    case and = "AND"
    case or = "OR"
}

// MARK: - Field Filter

/// A comparison between one field and one value.
///
/// For `in`, `not-in`, and `array-contains-any` the operand is a single `arrayValue` holding
/// every candidate; Firestore counts each element as a disjunction and caps the list.
public struct FieldFilter: QueryFilterProtocol {
    public let field: FieldReference
    public let op: FieldFilterOperator
    public let value: FirestoreValue

    public init(field: FieldReference, op: FieldFilterOperator, value: FirestoreValue) {
        self.field = field
        self.op = op
        self.value = value
    }

    public init(_ fieldPath: String, _ op: FieldFilterOperator, _ value: FirestoreValue) {
        self.field = FieldReference(fieldPath)
        self.op = op
        self.value = value
    }

    public func toJSON() -> [String: Any] {
        [
            "fieldFilter": [
                "field": field.toJSON(),
                "op": op.rawValue,
                "value": value.toJSON(),
            ]
        ]
    }
}

// MARK: - Unary Filter

/// A test on a field that takes no operand, for null and NaN.
public struct UnaryFilter: QueryFilterProtocol {
    public let field: FieldReference
    public let op: UnaryFilterOperator

    public init(field: FieldReference, op: UnaryFilterOperator) {
        self.field = field
        self.op = op
    }

    public init(_ fieldPath: String, _ op: UnaryFilterOperator) {
        self.field = FieldReference(fieldPath)
        self.op = op
    }

    public func toJSON() -> [String: Any] {
        [
            "unaryFilter": [
                "op": op.rawValue,
                "field": field.toJSON(),
            ]
        ]
    }
}

// MARK: - Composite Filter

/// A group of filters combined with AND or OR.
///
/// Groups nest, and Firestore evaluates the tree in disjunctive normal form, rejecting a query
/// whose expansion exceeds 30 disjunctions.
///
/// Equality and hashing both go through the rendered REST JSON, so two groups are equal only
/// when they hold the same clauses in the same order, and a clause that JSON cannot represent
/// — a filter comparing against a NaN or infinite double — contributes nothing to the hash.
public struct CompositeFilter: QueryFilterProtocol {
    public let op: CompositeFilterOperator
    public let filters: [any QueryFilterProtocol]

    public init(op: CompositeFilterOperator, filters: [any QueryFilterProtocol]) {
        self.op = op
        self.filters = filters
    }

    public static func and(_ filters: any QueryFilterProtocol...) -> CompositeFilter {
        CompositeFilter(op: .and, filters: filters)
    }

    public static func or(_ filters: any QueryFilterProtocol...) -> CompositeFilter {
        CompositeFilter(op: .or, filters: filters)
    }

    public func toJSON() -> [String: Any] {
        [
            "compositeFilter": [
                "op": op.rawValue,
                "filters": filters.map { $0.toJSON() },
            ]
        ]
    }

    // Hashable conformance for existential array
    public static func == (lhs: CompositeFilter, rhs: CompositeFilter) -> Bool {
        guard lhs.op == rhs.op else { return false }
        guard lhs.filters.count == rhs.filters.count else { return false }
        // Compare JSON representations for equality
        for (l, r) in zip(lhs.filters, rhs.filters) {
            let lJSON = l.toJSON()
            let rJSON = r.toJSON()
            guard NSDictionary(dictionary: lJSON).isEqual(to: rJSON) else { return false }
        }
        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(op)
        // Hash JSON representation
        for filter in filters {
            if let data = try? JSONSerialization.data(withJSONObject: filter.toJSON(), options: .sortedKeys) {
                hasher.combine(data)
            }
        }
    }
}

// MARK: - Query Filter (Type-Erased Wrapper)

/// A type-erased wrapper that lets any filter be stored or passed as a single concrete type.
///
/// Two wrappers are equal when their rendered REST JSON matches, so a wrapped filter can equal
/// a differently built filter that serializes identically. The hash, however, is copied from
/// the wrapped value's own `hashValue` at construction time, so equal wrappers built from
/// different concrete types can hash differently — do not rely on wrappers as `Set` members or
/// dictionary keys across mixed filter types.
public struct QueryFilter: QueryFilterProtocol {
    private let _toJSON: @Sendable () -> [String: Any]
    private let _hashValue: Int
    private let _isEqual: @Sendable (QueryFilter) -> Bool

    public init<F: QueryFilterProtocol>(_ filter: F) {
        self._toJSON = { filter.toJSON() }
        self._hashValue = filter.hashValue
        self._isEqual = { other in
            let selfJSON = filter.toJSON()
            let otherJSON = other.toJSON()
            return NSDictionary(dictionary: selfJSON).isEqual(to: otherJSON)
        }
    }

    public func toJSON() -> [String: Any] {
        _toJSON()
    }

    public static func == (lhs: QueryFilter, rhs: QueryFilter) -> Bool {
        lhs._isEqual(rhs)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(_hashValue)
    }
}

// MARK: - Convenience Filter Builders

public extension FieldFilter {
    /// Builds an `EQUAL` filter.
    static func isEqualTo(_ fieldPath: String, _ value: FirestoreValue) -> FieldFilter {
        FieldFilter(fieldPath, .equal, value)
    }

    /// Builds a `NOT_EQUAL` filter, which never matches a document that lacks the field.
    static func isNotEqualTo(_ fieldPath: String, _ value: FirestoreValue) -> FieldFilter {
        FieldFilter(fieldPath, .notEqual, value)
    }

    /// Builds a `LESS_THAN` filter, whose field must also be the query's first sort key.
    static func isLessThan(_ fieldPath: String, _ value: FirestoreValue) -> FieldFilter {
        FieldFilter(fieldPath, .lessThan, value)
    }

    /// Builds a `LESS_THAN_OR_EQUAL` filter, whose field must also be the query's first sort key.
    static func isLessThanOrEqual(_ fieldPath: String, _ value: FirestoreValue) -> FieldFilter {
        FieldFilter(fieldPath, .lessThanOrEqual, value)
    }

    /// Builds a `GREATER_THAN` filter, whose field must also be the query's first sort key.
    static func isGreaterThan(_ fieldPath: String, _ value: FirestoreValue) -> FieldFilter {
        FieldFilter(fieldPath, .greaterThan, value)
    }

    /// Builds a `GREATER_THAN_OR_EQUAL` filter, whose field must also be the query's first sort key.
    static func isGreaterThanOrEqual(_ fieldPath: String, _ value: FirestoreValue) -> FieldFilter {
        FieldFilter(fieldPath, .greaterThanOrEqual, value)
    }

    /// Builds an `ARRAY_CONTAINS` filter, of which Firestore allows one per query.
    static func arrayContains(_ fieldPath: String, _ value: FirestoreValue) -> FieldFilter {
        FieldFilter(fieldPath, .arrayContains, value)
    }

    /// Builds an `IN` filter, wrapping the candidates in a single `arrayValue`.
    ///
    /// Firestore caps the list at 30 values and counts each one against the query's
    /// 30-disjunction budget; nothing here checks the count.
    static func isIn(_ fieldPath: String, _ values: [FirestoreValue]) -> FieldFilter {
        FieldFilter(fieldPath, .in, .array(values))
    }

    /// Builds an `ARRAY_CONTAINS_ANY` filter, wrapping the candidates in a single `arrayValue`.
    ///
    /// Firestore caps the list at 30 values, allows one such clause per query, and refuses to
    /// combine it with `ARRAY_CONTAINS`.
    static func arrayContainsAny(_ fieldPath: String, _ values: [FirestoreValue]) -> FieldFilter {
        FieldFilter(fieldPath, .arrayContainsAny, .array(values))
    }

    /// Builds a `NOT_IN` filter, wrapping the candidates in a single `arrayValue`.
    ///
    /// Firestore caps the list, drops documents that lack the field, and refuses to combine
    /// `NOT_IN` with `IN`, `ARRAY_CONTAINS_ANY`, or `NOT_EQUAL`.
    static func isNotIn(_ fieldPath: String, _ values: [FirestoreValue]) -> FieldFilter {
        FieldFilter(fieldPath, .notIn, .array(values))
    }
}

public extension UnaryFilter {
    /// Builds an `IS_NULL` filter, which does not match documents that omit the field.
    static func isNull(_ fieldPath: String) -> UnaryFilter {
        UnaryFilter(fieldPath, .isNull)
    }

    /// Builds an `IS_NOT_NULL` filter, which matches only documents that carry the field.
    static func isNotNull(_ fieldPath: String) -> UnaryFilter {
        UnaryFilter(fieldPath, .isNotNull)
    }

    /// Builds an `IS_NAN` filter, the only way to match the double NaN.
    static func isNaN(_ fieldPath: String) -> UnaryFilter {
        UnaryFilter(fieldPath, .isNaN)
    }

    /// Builds an `IS_NOT_NAN` filter, which matches only documents that carry the field.
    static func isNotNaN(_ fieldPath: String) -> UnaryFilter {
        UnaryFilter(fieldPath, .isNotNaN)
    }
}
