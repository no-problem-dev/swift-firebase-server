import Foundation

// MARK: - Query Filter Protocol

/// クエリフィルターを表すプロトコル
public protocol QueryFilterProtocol: Sendable, Hashable {
    /// REST API用のJSONに変換
    func toJSON() -> [String: Any]
}

// MARK: - Field Filter Operator

/// フィールドフィルターの比較演算子
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

/// 単項フィルターの演算子
public enum UnaryFilterOperator: String, Sendable, Hashable {
    case isNaN = "IS_NAN"
    case isNull = "IS_NULL"
    case isNotNaN = "IS_NOT_NAN"
    case isNotNull = "IS_NOT_NULL"
}

// MARK: - Composite Filter Operator

/// 複合フィルターの演算子
public enum CompositeFilterOperator: String, Sendable, Hashable {
    case and = "AND"
    case or = "OR"
}

// MARK: - Field Filter

/// フィールド値に対するフィルター
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

/// 単項フィルター（null/nan判定）
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

/// 複数フィルターの複合（AND/OR）
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

/// 任意のフィルターを包むラッパー型
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
    /// フィールドが値と等しい
    static func isEqualTo(_ fieldPath: String, _ value: FirestoreValue) -> FieldFilter {
        FieldFilter(fieldPath, .equal, value)
    }

    /// フィールドが値と等しくない
    static func isNotEqualTo(_ fieldPath: String, _ value: FirestoreValue) -> FieldFilter {
        FieldFilter(fieldPath, .notEqual, value)
    }

    /// フィールドが値より小さい
    static func isLessThan(_ fieldPath: String, _ value: FirestoreValue) -> FieldFilter {
        FieldFilter(fieldPath, .lessThan, value)
    }

    /// フィールドが値以下
    static func isLessThanOrEqual(_ fieldPath: String, _ value: FirestoreValue) -> FieldFilter {
        FieldFilter(fieldPath, .lessThanOrEqual, value)
    }

    /// フィールドが値より大きい
    static func isGreaterThan(_ fieldPath: String, _ value: FirestoreValue) -> FieldFilter {
        FieldFilter(fieldPath, .greaterThan, value)
    }

    /// フィールドが値以上
    static func isGreaterThanOrEqual(_ fieldPath: String, _ value: FirestoreValue) -> FieldFilter {
        FieldFilter(fieldPath, .greaterThanOrEqual, value)
    }

    /// 配列フィールドが値を含む
    static func arrayContains(_ fieldPath: String, _ value: FirestoreValue) -> FieldFilter {
        FieldFilter(fieldPath, .arrayContains, value)
    }

    /// フィールドが配列内のいずれかの値と等しい
    static func isIn(_ fieldPath: String, _ values: [FirestoreValue]) -> FieldFilter {
        FieldFilter(fieldPath, .in, .array(values))
    }

    /// 配列フィールドが配列内のいずれかの値を含む
    static func arrayContainsAny(_ fieldPath: String, _ values: [FirestoreValue]) -> FieldFilter {
        FieldFilter(fieldPath, .arrayContainsAny, .array(values))
    }

    /// フィールドが配列内のいずれの値とも等しくない
    static func isNotIn(_ fieldPath: String, _ values: [FirestoreValue]) -> FieldFilter {
        FieldFilter(fieldPath, .notIn, .array(values))
    }
}

public extension UnaryFilter {
    /// フィールドがnull
    static func isNull(_ fieldPath: String) -> UnaryFilter {
        UnaryFilter(fieldPath, .isNull)
    }

    /// フィールドがnullでない
    static func isNotNull(_ fieldPath: String) -> UnaryFilter {
        UnaryFilter(fieldPath, .isNotNull)
    }

    /// フィールドがNaN
    static func isNaN(_ fieldPath: String) -> UnaryFilter {
        UnaryFilter(fieldPath, .isNaN)
    }

    /// フィールドがNaNでない
    static func isNotNaN(_ fieldPath: String) -> UnaryFilter {
        UnaryFilter(fieldPath, .isNotNaN)
    }
}
