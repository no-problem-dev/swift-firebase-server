import Foundation

// MARK: - Query Protocol

/// Firestoreクエリを構築するためのプロトコル
public protocol FirestoreQueryProtocol: Sendable {
    associatedtype ResultType

    /// コレクション参照
    var collection: CollectionReference { get }

    /// REST API用のStructuredQueryを生成
    func buildStructuredQuery() -> [String: Any]
}

// MARK: - Query

/// Firestoreクエリを構築するビルダー
public struct Query<T>: FirestoreQueryProtocol, Sendable where T: Decodable & Sendable {
    public typealias ResultType = T

    public let collection: CollectionReference

    // Query components
    let collectionSelectors: [CollectionSelector]
    let filter: QueryFilter?
    let orderByClause: [QueryOrder]
    let startAtCursor: QueryCursor?
    let endAtCursor: QueryCursor?
    let limitCount: Int?
    let offsetCount: Int?
    let projection: QueryProjection?

    // Internal initializer for builder pattern
    init(
        collection: CollectionReference,
        collectionSelectors: [CollectionSelector]? = nil,
        filter: QueryFilter? = nil,
        orderBy: [QueryOrder] = [],
        startAt: QueryCursor? = nil,
        endAt: QueryCursor? = nil,
        limit: Int? = nil,
        offset: Int? = nil,
        projection: QueryProjection? = nil
    ) {
        self.collection = collection
        self.collectionSelectors = collectionSelectors ?? [CollectionSelector(collectionId: collection.collectionId)]
        self.filter = filter
        self.orderByClause = orderBy
        self.startAtCursor = startAt
        self.endAtCursor = endAt
        self.limitCount = limit
        self.offsetCount = offset
        self.projection = projection
    }

    // MARK: - Builder Methods

    /// フィルター条件を追加
    public func `where`(_ filter: some QueryFilterProtocol) -> Query<T> {
        Query(
            collection: collection,
            collectionSelectors: collectionSelectors,
            filter: QueryFilter(filter),
            orderBy: orderByClause,
            startAt: startAtCursor,
            endAt: endAtCursor,
            limit: limitCount,
            offset: offsetCount,
            projection: projection
        )
    }

    /// フィールドが値と等しい条件を追加
    public func whereField(_ fieldPath: String, isEqualTo value: FirestoreValue) -> Query<T> {
        self.where(FieldFilter.isEqualTo(fieldPath, value))
    }

    /// フィールドが値と等しくない条件を追加
    public func whereField(_ fieldPath: String, isNotEqualTo value: FirestoreValue) -> Query<T> {
        self.where(FieldFilter.isNotEqualTo(fieldPath, value))
    }

    /// フィールドが値より小さい条件を追加
    public func whereField(_ fieldPath: String, isLessThan value: FirestoreValue) -> Query<T> {
        self.where(FieldFilter.isLessThan(fieldPath, value))
    }

    /// フィールドが値以下の条件を追加
    public func whereField(_ fieldPath: String, isLessThanOrEqualTo value: FirestoreValue) -> Query<T> {
        self.where(FieldFilter.isLessThanOrEqual(fieldPath, value))
    }

    /// フィールドが値より大きい条件を追加
    public func whereField(_ fieldPath: String, isGreaterThan value: FirestoreValue) -> Query<T> {
        self.where(FieldFilter.isGreaterThan(fieldPath, value))
    }

    /// フィールドが値以上の条件を追加
    public func whereField(_ fieldPath: String, isGreaterThanOrEqualTo value: FirestoreValue) -> Query<T> {
        self.where(FieldFilter.isGreaterThanOrEqual(fieldPath, value))
    }

    /// 配列フィールドが値を含む条件を追加
    public func whereField(_ fieldPath: String, arrayContains value: FirestoreValue) -> Query<T> {
        self.where(FieldFilter.arrayContains(fieldPath, value))
    }

    /// フィールドが配列内のいずれかの値と等しい条件を追加
    public func whereField(_ fieldPath: String, in values: [FirestoreValue]) -> Query<T> {
        self.where(FieldFilter.isIn(fieldPath, values))
    }

    /// 配列フィールドが配列内のいずれかの値を含む条件を追加
    public func whereField(_ fieldPath: String, arrayContainsAny values: [FirestoreValue]) -> Query<T> {
        self.where(FieldFilter.arrayContainsAny(fieldPath, values))
    }

    /// フィールドが配列内のいずれの値とも等しくない条件を追加
    public func whereField(_ fieldPath: String, notIn values: [FirestoreValue]) -> Query<T> {
        self.where(FieldFilter.isNotIn(fieldPath, values))
    }

    /// フィルター条件を組み合わせる（AND）
    public func whereAnd(_ filters: any QueryFilterProtocol...) -> Query<T> {
        self.where(CompositeFilter.and(filters))
    }

    /// フィルター条件を組み合わせる（OR）
    public func whereOr(_ filters: any QueryFilterProtocol...) -> Query<T> {
        self.where(CompositeFilter.or(filters))
    }

    /// ソート順を追加
    public func order(by fieldPath: String, direction: SortDirection = .ascending) -> Query<T> {
        var newOrderBy = orderByClause
        newOrderBy.append(QueryOrder(fieldPath, direction: direction))
        return Query(
            collection: collection,
            collectionSelectors: collectionSelectors,
            filter: filter,
            orderBy: newOrderBy,
            startAt: startAtCursor,
            endAt: endAtCursor,
            limit: limitCount,
            offset: offsetCount,
            projection: projection
        )
    }

    /// 昇順ソートを追加
    public func orderAscending(by fieldPath: String) -> Query<T> {
        order(by: fieldPath, direction: .ascending)
    }

    /// 降順ソートを追加
    public func orderDescending(by fieldPath: String) -> Query<T> {
        order(by: fieldPath, direction: .descending)
    }

    /// 取得件数を制限
    public func limit(to count: Int) -> Query<T> {
        Query(
            collection: collection,
            collectionSelectors: collectionSelectors,
            filter: filter,
            orderBy: orderByClause,
            startAt: startAtCursor,
            endAt: endAtCursor,
            limit: count,
            offset: offsetCount,
            projection: projection
        )
    }

    /// 開始位置をオフセット
    public func offset(_ count: Int) -> Query<T> {
        Query(
            collection: collection,
            collectionSelectors: collectionSelectors,
            filter: filter,
            orderBy: orderByClause,
            startAt: startAtCursor,
            endAt: endAtCursor,
            limit: limitCount,
            offset: count,
            projection: projection
        )
    }

    /// 開始カーソルを設定
    public func start(at values: FirestoreValue...) -> Query<T> {
        Query(
            collection: collection,
            collectionSelectors: collectionSelectors,
            filter: filter,
            orderBy: orderByClause,
            startAt: QueryCursor(values: values, before: false),
            endAt: endAtCursor,
            limit: limitCount,
            offset: offsetCount,
            projection: projection
        )
    }

    /// 開始カーソルを設定（指定値の直後から）
    public func start(after values: FirestoreValue...) -> Query<T> {
        Query(
            collection: collection,
            collectionSelectors: collectionSelectors,
            filter: filter,
            orderBy: orderByClause,
            startAt: QueryCursor(values: values, before: true),
            endAt: endAtCursor,
            limit: limitCount,
            offset: offsetCount,
            projection: projection
        )
    }

    /// 終了カーソルを設定
    public func end(at values: FirestoreValue...) -> Query<T> {
        Query(
            collection: collection,
            collectionSelectors: collectionSelectors,
            filter: filter,
            orderBy: orderByClause,
            startAt: startAtCursor,
            endAt: QueryCursor(values: values, before: false),
            limit: limitCount,
            offset: offsetCount,
            projection: projection
        )
    }

    /// 終了カーソルを設定（指定値の直前まで）
    public func end(before values: FirestoreValue...) -> Query<T> {
        Query(
            collection: collection,
            collectionSelectors: collectionSelectors,
            filter: filter,
            orderBy: orderByClause,
            startAt: startAtCursor,
            endAt: QueryCursor(values: values, before: true),
            limit: limitCount,
            offset: offsetCount,
            projection: projection
        )
    }

    /// 取得するフィールドを制限
    public func select(_ fieldPaths: String...) -> Query<T> {
        Query(
            collection: collection,
            collectionSelectors: collectionSelectors,
            filter: filter,
            orderBy: orderByClause,
            startAt: startAtCursor,
            endAt: endAtCursor,
            limit: limitCount,
            offset: offsetCount,
            projection: QueryProjection(fieldPaths: Array(fieldPaths))
        )
    }

    /// サブコレクションも含めてクエリ（コレクショングループクエリ）
    public func collectionGroup() -> Query<T> {
        Query(
            collection: collection,
            collectionSelectors: [CollectionSelector(collectionId: collection.collectionId, allDescendants: true)],
            filter: filter,
            orderBy: orderByClause,
            startAt: startAtCursor,
            endAt: endAtCursor,
            limit: limitCount,
            offset: offsetCount,
            projection: projection
        )
    }

    // MARK: - Build StructuredQuery

    public func buildStructuredQuery() -> [String: Any] {
        var query: [String: Any] = [:]

        // from
        query["from"] = collectionSelectors.map { $0.toJSON() }

        // where
        if let filter = filter {
            query["where"] = filter.toJSON()
        }

        // select
        if let projection = projection {
            query["select"] = projection.toJSON()
        }

        // orderBy
        if !orderByClause.isEmpty {
            query["orderBy"] = orderByClause.map { $0.toJSON() }
        }

        // startAt
        if let startAt = startAtCursor {
            query["startAt"] = startAt.toJSON()
        }

        // endAt
        if let endAt = endAtCursor {
            query["endAt"] = endAt.toJSON()
        }

        // offset
        if let offset = offsetCount {
            query["offset"] = offset
        }

        // limit
        if let limit = limitCount {
            query["limit"] = limit
        }

        return query
    }
}

// MARK: - CompositeFilter convenience for variadic

extension CompositeFilter {
    static func and(_ filters: [any QueryFilterProtocol]) -> CompositeFilter {
        CompositeFilter(op: .and, filters: filters)
    }

    static func or(_ filters: [any QueryFilterProtocol]) -> CompositeFilter {
        CompositeFilter(op: .or, filters: filters)
    }
}
