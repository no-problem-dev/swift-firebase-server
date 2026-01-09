import Foundation
import Testing
@testable import FirestoreServer

@Suite("Query Tests")
struct QueryTests {
    let database = DatabasePath(projectId: "test-project", databaseId: "(default)")

    // MARK: - Field Reference Tests

    @Test("FieldReference - basic field path")
    func fieldReferenceBasic() {
        let field = FieldReference("name")
        #expect(field.fieldPath == "name")

        let json = field.toJSON()
        #expect(json["fieldPath"] as? String == "name")
    }

    @Test("FieldReference - nested field path")
    func fieldReferenceNested() {
        let field = FieldReference("address.city")
        #expect(field.fieldPath == "address.city")
    }

    @Test("FieldReference - document ID")
    func fieldReferenceDocumentId() {
        let field = FieldReference.documentId
        #expect(field.fieldPath == "__name__")
    }

    // MARK: - Query Order Tests

    @Test("QueryOrder - ascending")
    func queryOrderAscending() {
        let order = QueryOrder("createdAt", direction: .ascending)
        let json = order.toJSON()

        let fieldJSON = json["field"] as? [String: Any]
        #expect(fieldJSON?["fieldPath"] as? String == "createdAt")
        #expect(json["direction"] as? String == "ASCENDING")
    }

    @Test("QueryOrder - descending")
    func queryOrderDescending() {
        let order = QueryOrder("updatedAt", direction: .descending)
        let json = order.toJSON()

        #expect(json["direction"] as? String == "DESCENDING")
    }

    // MARK: - Field Filter Tests

    @Test("FieldFilter - equal")
    func fieldFilterEqual() {
        let filter = FieldFilter.isEqualTo("status", .string("active"))
        let json = filter.toJSON()

        let fieldFilter = json["fieldFilter"] as? [String: Any]
        #expect(fieldFilter != nil)

        let field = fieldFilter?["field"] as? [String: Any]
        #expect(field?["fieldPath"] as? String == "status")
        #expect(fieldFilter?["op"] as? String == "EQUAL")

        let value = fieldFilter?["value"] as? [String: Any]
        #expect(value?["stringValue"] as? String == "active")
    }

    @Test("FieldFilter - greater than")
    func fieldFilterGreaterThan() {
        let filter = FieldFilter.isGreaterThan("age", .integer(18))
        let json = filter.toJSON()

        let fieldFilter = json["fieldFilter"] as? [String: Any]
        #expect(fieldFilter?["op"] as? String == "GREATER_THAN")
    }

    @Test("FieldFilter - array contains")
    func fieldFilterArrayContains() {
        let filter = FieldFilter.arrayContains("tags", .string("swift"))
        let json = filter.toJSON()

        let fieldFilter = json["fieldFilter"] as? [String: Any]
        #expect(fieldFilter?["op"] as? String == "ARRAY_CONTAINS")
    }

    @Test("FieldFilter - in")
    func fieldFilterIn() {
        let filter = FieldFilter.isIn("status", [.string("active"), .string("pending")])
        let json = filter.toJSON()

        let fieldFilter = json["fieldFilter"] as? [String: Any]
        #expect(fieldFilter?["op"] as? String == "IN")

        let value = fieldFilter?["value"] as? [String: Any]
        let arrayValue = value?["arrayValue"] as? [String: Any]
        #expect(arrayValue != nil)
    }

    // MARK: - Unary Filter Tests

    @Test("UnaryFilter - isNull")
    func unaryFilterIsNull() {
        let filter = UnaryFilter.isNull("deletedAt")
        let json = filter.toJSON()

        let unaryFilter = json["unaryFilter"] as? [String: Any]
        #expect(unaryFilter?["op"] as? String == "IS_NULL")

        let field = unaryFilter?["field"] as? [String: Any]
        #expect(field?["fieldPath"] as? String == "deletedAt")
    }

    @Test("UnaryFilter - isNotNull")
    func unaryFilterIsNotNull() {
        let filter = UnaryFilter.isNotNull("email")
        let json = filter.toJSON()

        let unaryFilter = json["unaryFilter"] as? [String: Any]
        #expect(unaryFilter?["op"] as? String == "IS_NOT_NULL")
    }

    // MARK: - Composite Filter Tests

    @Test("CompositeFilter - AND")
    func compositeFilterAnd() {
        let filter = CompositeFilter.and(
            FieldFilter.isEqualTo("status", .string("active")),
            FieldFilter.isGreaterThan("age", .integer(18))
        )
        let json = filter.toJSON()

        let compositeFilter = json["compositeFilter"] as? [String: Any]
        #expect(compositeFilter?["op"] as? String == "AND")

        let filters = compositeFilter?["filters"] as? [[String: Any]]
        #expect(filters?.count == 2)
    }

    @Test("CompositeFilter - OR")
    func compositeFilterOr() {
        let filter = CompositeFilter.or(
            FieldFilter.isEqualTo("type", .string("admin")),
            FieldFilter.isEqualTo("type", .string("moderator"))
        )
        let json = filter.toJSON()

        let compositeFilter = json["compositeFilter"] as? [String: Any]
        #expect(compositeFilter?["op"] as? String == "OR")
    }

    // MARK: - Query Builder Tests

    @Test("Query - basic where clause")
    func queryBasicWhere() throws {
        let collectionPath = try CollectionPath("users")
        let collection = CollectionReference(database: database, path: collectionPath)

        struct User: Codable { let name: String }

        let query = collection.query(as: User.self)
            .whereField(FieldPath("status"), isEqualTo: .string("active"))

        let structuredQuery = query.buildStructuredQuery()

        let from = structuredQuery["from"] as? [[String: Any]]
        #expect(from?.first?["collectionId"] as? String == "users")

        let whereClause = structuredQuery["where"] as? [String: Any]
        #expect(whereClause != nil)
    }

    @Test("Query - order by")
    func queryOrderBy() throws {
        let collectionPath = try CollectionPath("posts")
        let collection = CollectionReference(database: database, path: collectionPath)

        struct Post: Codable { let title: String }

        let query = collection.query(as: Post.self)
            .orderDescending(by: FieldPath("createdAt"))

        let structuredQuery = query.buildStructuredQuery()

        let orderBy = structuredQuery["orderBy"] as? [[String: Any]]
        #expect(orderBy?.count == 1)

        let firstOrder = orderBy?.first
        let field = firstOrder?["field"] as? [String: Any]
        #expect(field?["fieldPath"] as? String == "createdAt")
        #expect(firstOrder?["direction"] as? String == "DESCENDING")
    }

    @Test("Query - limit and offset")
    func queryLimitOffset() throws {
        let collectionPath = try CollectionPath("items")
        let collection = CollectionReference(database: database, path: collectionPath)

        struct Item: Codable { let id: String }

        let query = collection.query(as: Item.self)
            .limit(to: 10)
            .offset(20)

        let structuredQuery = query.buildStructuredQuery()

        #expect(structuredQuery["limit"] as? Int == 10)
        #expect(structuredQuery["offset"] as? Int == 20)
    }

    @Test("Query - multiple conditions chained")
    func queryChained() throws {
        let collectionPath = try CollectionPath("products")
        let collection = CollectionReference(database: database, path: collectionPath)

        struct Product: Codable {
            let name: String
            let price: Double
        }

        let query = collection.query(as: Product.self)
            .whereField(FieldPath("category"), isEqualTo: .string("electronics"))
            .orderDescending(by: FieldPath("price"))
            .limit(to: 20)

        let structuredQuery = query.buildStructuredQuery()

        #expect(structuredQuery["where"] != nil)
        #expect(structuredQuery["orderBy"] != nil)
        #expect(structuredQuery["limit"] as? Int == 20)
    }

    @Test("Query - collection group")
    func queryCollectionGroup() throws {
        let collectionPath = try CollectionPath("comments")
        let collection = CollectionReference(database: database, path: collectionPath)

        struct Comment: Codable { let text: String }

        let query = collection.query(as: Comment.self)
            .collectionGroup()

        let structuredQuery = query.buildStructuredQuery()

        let from = structuredQuery["from"] as? [[String: Any]]
        #expect(from?.first?["allDescendants"] as? Bool == true)
    }

    @Test("Query - select projection")
    func querySelectProjection() throws {
        let collectionPath = try CollectionPath("users")
        let collection = CollectionReference(database: database, path: collectionPath)

        struct User: Codable { let name: String }

        let query = collection.query(as: User.self)
            .select(FieldPath("name"), FieldPath("email"))

        let structuredQuery = query.buildStructuredQuery()

        let select = structuredQuery["select"] as? [String: Any]
        let fields = select?["fields"] as? [[String: Any]]
        #expect(fields?.count == 2)
    }

    @Test("Query - cursors")
    func queryCursors() throws {
        let collectionPath = try CollectionPath("logs")
        let collection = CollectionReference(database: database, path: collectionPath)

        struct Log: Codable { let message: String }

        let query = collection.query(as: Log.self)
            .orderDescending(by: FieldPath("timestamp"))
            .start(at: .integer(1000))
            .end(at: .integer(2000))

        let structuredQuery = query.buildStructuredQuery()

        let startAt = structuredQuery["startAt"] as? [String: Any]
        #expect(startAt != nil)

        let endAt = structuredQuery["endAt"] as? [String: Any]
        #expect(endAt != nil)
    }

    // MARK: - Complex Query Tests

    @Test("Query - complex filter with AND")
    func queryComplexAnd() throws {
        let collectionPath = try CollectionPath("orders")
        let collection = CollectionReference(database: database, path: collectionPath)

        struct Order: Codable {
            let status: String
            let total: Double
        }

        let query = collection.query(as: Order.self)
            .where(CompositeFilter.and(
                FieldFilter.isEqualTo("status", .string("completed")),
                FieldFilter.isGreaterThan("total", .double(100.0))
            ))

        let structuredQuery = query.buildStructuredQuery()
        let whereClause = structuredQuery["where"] as? [String: Any]
        let compositeFilter = whereClause?["compositeFilter"] as? [String: Any]
        #expect(compositeFilter?["op"] as? String == "AND")
    }

    @Test("Query - complex filter with OR")
    func queryComplexOr() throws {
        let collectionPath = try CollectionPath("users")
        let collection = CollectionReference(database: database, path: collectionPath)

        struct User: Codable { let role: String }

        let query = collection.query(as: User.self)
            .where(CompositeFilter.or(
                FieldFilter.isEqualTo("role", .string("admin")),
                FieldFilter.isEqualTo("role", .string("moderator"))
            ))

        let structuredQuery = query.buildStructuredQuery()
        let whereClause = structuredQuery["where"] as? [String: Any]
        let compositeFilter = whereClause?["compositeFilter"] as? [String: Any]
        #expect(compositeFilter?["op"] as? String == "OR")
    }
}
