import Foundation

// MARK: - FieldPath

public struct FieldPath<Model>: Sendable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

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
    ///
    /// 既存のフィルターがある場合はANDで結合します。
    /// これによりwhereField()をチェーンした場合に正しく動作します。
    public func `where`(_ filter: some QueryFilterProtocol) -> Query<T> {
        let combinedFilter: QueryFilter
        if let existingFilter = self.filter {
            // 既存フィルターと新規フィルターをANDで結合
            combinedFilter = QueryFilter(CompositeFilter(op: .and, filters: [existingFilter, filter]))
        } else {
            combinedFilter = QueryFilter(filter)
        }
        return Query(
            collection: collection,
            collectionSelectors: collectionSelectors,
            filter: combinedFilter,
            orderBy: orderByClause,
            startAt: startAtCursor,
            endAt: endAtCursor,
            limit: limitCount,
            offset: offsetCount,
            projection: projection
        )
    }

    public func whereField(_ field: FieldPath<T>, isEqualTo value: FirestoreValue) -> Query<T> {
        self.where(FieldFilter.isEqualTo(field.rawValue, value))
    }

    public func whereField(_ field: FieldPath<T>, isNotEqualTo value: FirestoreValue) -> Query<T> {
        self.where(FieldFilter.isNotEqualTo(field.rawValue, value))
    }

    public func whereField(_ field: FieldPath<T>, isLessThan value: FirestoreValue) -> Query<T> {
        self.where(FieldFilter.isLessThan(field.rawValue, value))
    }

    public func whereField(_ field: FieldPath<T>, isLessThanOrEqualTo value: FirestoreValue) -> Query<T> {
        self.where(FieldFilter.isLessThanOrEqual(field.rawValue, value))
    }

    public func whereField(_ field: FieldPath<T>, isGreaterThan value: FirestoreValue) -> Query<T> {
        self.where(FieldFilter.isGreaterThan(field.rawValue, value))
    }

    public func whereField(_ field: FieldPath<T>, isGreaterThanOrEqualTo value: FirestoreValue) -> Query<T> {
        self.where(FieldFilter.isGreaterThanOrEqual(field.rawValue, value))
    }

    public func whereField(_ field: FieldPath<T>, arrayContains value: FirestoreValue) -> Query<T> {
        self.where(FieldFilter.arrayContains(field.rawValue, value))
    }

    public func whereField(_ field: FieldPath<T>, in values: [FirestoreValue]) -> Query<T> {
        self.where(FieldFilter.isIn(field.rawValue, values))
    }

    public func whereField(_ field: FieldPath<T>, arrayContainsAny values: [FirestoreValue]) -> Query<T> {
        self.where(FieldFilter.arrayContainsAny(field.rawValue, values))
    }

    public func whereField(_ field: FieldPath<T>, notIn values: [FirestoreValue]) -> Query<T> {
        self.where(FieldFilter.isNotIn(field.rawValue, values))
    }

    public func whereAnd(_ filters: any QueryFilterProtocol...) -> Query<T> {
        self.where(CompositeFilter.and(filters))
    }

    public func whereOr(_ filters: any QueryFilterProtocol...) -> Query<T> {
        self.where(CompositeFilter.or(filters))
    }

    public func order(by field: FieldPath<T>, direction: SortDirection = .ascending) -> Query<T> {
        var newOrderBy = orderByClause
        newOrderBy.append(QueryOrder(field.rawValue, direction: direction))
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

    public func orderAscending(by field: FieldPath<T>) -> Query<T> {
        order(by: field, direction: .ascending)
    }

    public func orderDescending(by field: FieldPath<T>) -> Query<T> {
        order(by: field, direction: .descending)
    }

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

    public func select(_ fields: FieldPath<T>...) -> Query<T> {
        Query(
            collection: collection,
            collectionSelectors: collectionSelectors,
            filter: filter,
            orderBy: orderByClause,
            startAt: startAtCursor,
            endAt: endAtCursor,
            limit: limitCount,
            offset: offsetCount,
            projection: QueryProjection(fieldPaths: fields.map(\.rawValue))
        )
    }

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
