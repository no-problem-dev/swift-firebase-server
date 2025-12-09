import Foundation

// MARK: - Field Reference

/// Firestoreフィールドへの参照
public struct FieldReference: Sendable, Hashable {
    /// フィールドパス（ネストされたフィールドはドット区切り）
    public let fieldPath: String

    public init(_ fieldPath: String) {
        self.fieldPath = fieldPath
    }

    /// ドキュメントID疑似フィールド
    public static let documentId = FieldReference("__name__")

    func toJSON() -> [String: Any] {
        ["fieldPath": fieldPath]
    }
}

// MARK: - Sort Direction

/// ソート方向
public enum SortDirection: String, Sendable, Hashable {
    case ascending = "ASCENDING"
    case descending = "DESCENDING"
}

// MARK: - Order

/// クエリ結果の並び順を指定
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

/// クエリカーソル（startAt/endAtに使用）
public struct QueryCursor: Sendable, Hashable {
    public let values: [FirestoreValue]
    public let before: Bool

    /// カーソル位置を指定（指定値を含む）
    public static func at(_ values: FirestoreValue...) -> QueryCursor {
        QueryCursor(values: values, before: false)
    }

    /// カーソル位置を指定（指定値の直前）
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

/// 取得するフィールドの制限
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

/// クエリ対象のコレクション指定
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
