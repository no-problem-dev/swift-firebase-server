import Foundation

/// フィールド参照を表す構造体
///
/// FilterBuilder DSL でフィールドを指定する際に使用する。
/// 演算子オーバーロードで直感的なフィルター条件を記述できる。
///
/// ## 使用例
///
/// ```swift
/// // 基本的な比較
/// query.filter {
///     Field("status") == "active"
///     Field("age") >= 18
///     Field("price") < 100.0
/// }
///
/// // 配列・NULL操作
/// query.filter {
///     Field("tags").contains("swift")
///     Field("role").in(["admin", "moderator"])
///     Field("deletedAt").isNull
/// }
/// ```
public struct Field: Sendable {
    /// フィールドパス
    public let path: String

    /// フィールド参照を作成
    /// - Parameter path: フィールドパス（ネストは`.`で区切る）
    public init(_ path: String) {
        self.path = path
    }
}

// MARK: - Comparison Operators

/// 等価演算子（==）
/// - Returns: 等値フィルター
public func == <V: FirestoreValueConvertible>(lhs: Field, rhs: V) -> FieldFilter {
    FieldFilter(
        field: FieldReference(lhs.path),
        op: .equal,
        value: rhs.toFirestoreValue()
    )
}

/// 不等価演算子（!=）
/// - Returns: 不等値フィルター
public func != <V: FirestoreValueConvertible>(lhs: Field, rhs: V) -> FieldFilter {
    FieldFilter(
        field: FieldReference(lhs.path),
        op: .notEqual,
        value: rhs.toFirestoreValue()
    )
}

/// 小なり演算子（<）
/// - Returns: 小なりフィルター
public func < <V: FirestoreValueConvertible>(lhs: Field, rhs: V) -> FieldFilter {
    FieldFilter(
        field: FieldReference(lhs.path),
        op: .lessThan,
        value: rhs.toFirestoreValue()
    )
}

/// 小なりイコール演算子（<=）
/// - Returns: 小なりイコールフィルター
public func <= <V: FirestoreValueConvertible>(lhs: Field, rhs: V) -> FieldFilter {
    FieldFilter(
        field: FieldReference(lhs.path),
        op: .lessThanOrEqual,
        value: rhs.toFirestoreValue()
    )
}

/// 大なり演算子（>）
/// - Returns: 大なりフィルター
public func > <V: FirestoreValueConvertible>(lhs: Field, rhs: V) -> FieldFilter {
    FieldFilter(
        field: FieldReference(lhs.path),
        op: .greaterThan,
        value: rhs.toFirestoreValue()
    )
}

/// 大なりイコール演算子（>=）
/// - Returns: 大なりイコールフィルター
public func >= <V: FirestoreValueConvertible>(lhs: Field, rhs: V) -> FieldFilter {
    FieldFilter(
        field: FieldReference(lhs.path),
        op: .greaterThanOrEqual,
        value: rhs.toFirestoreValue()
    )
}

// MARK: - Array & Special Operations

extension Field {
    /// 配列フィールドが指定値を含むかチェック
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

    /// 配列フィールドが指定配列のいずれかの値を含むかチェック
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

    /// フィールド値が指定配列のいずれかに一致するかチェック
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

    /// フィールド値が指定配列のいずれにも一致しないかチェック
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

    /// フィールドがNULLかチェック（UnaryFilter）
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

    /// フィールドがNULLでないかチェック（UnaryFilter）
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

    /// フィールドがNaNかチェック（UnaryFilter）
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

    /// フィールドがNaNでないかチェック（UnaryFilter）
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
