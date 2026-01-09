import Foundation
import Testing
@testable import FirestoreServer

@Suite("FilterBuilder DSL Tests")
struct FilterBuilderTests {
    let database = DatabasePath(projectId: "test-project", databaseId: "(default)")

    // MARK: - Field Operator Tests

    @Test("Field - equal operator")
    func fieldEqual() {
        let filter = Field("status") == "active"

        let json = filter.toJSON()
        let fieldFilter = json["fieldFilter"] as? [String: Any]

        let field = fieldFilter?["field"] as? [String: Any]
        #expect(field?["fieldPath"] as? String == "status")
        #expect(fieldFilter?["op"] as? String == "EQUAL")

        let value = fieldFilter?["value"] as? [String: Any]
        #expect(value?["stringValue"] as? String == "active")
    }

    @Test("Field - not equal operator")
    func fieldNotEqual() {
        let filter = Field("status") != "deleted"

        let json = filter.toJSON()
        let fieldFilter = json["fieldFilter"] as? [String: Any]
        #expect(fieldFilter?["op"] as? String == "NOT_EQUAL")
    }

    @Test("Field - less than operator")
    func fieldLessThan() {
        let filter = Field("price") < 100.0

        let json = filter.toJSON()
        let fieldFilter = json["fieldFilter"] as? [String: Any]
        #expect(fieldFilter?["op"] as? String == "LESS_THAN")

        let value = fieldFilter?["value"] as? [String: Any]
        #expect(value?["doubleValue"] as? Double == 100.0)
    }

    @Test("Field - less than or equal operator")
    func fieldLessThanOrEqual() {
        let filter = Field("age") <= 18

        let json = filter.toJSON()
        let fieldFilter = json["fieldFilter"] as? [String: Any]
        #expect(fieldFilter?["op"] as? String == "LESS_THAN_OR_EQUAL")
    }

    @Test("Field - greater than operator")
    func fieldGreaterThan() {
        let filter = Field("score") > 50

        let json = filter.toJSON()
        let fieldFilter = json["fieldFilter"] as? [String: Any]
        #expect(fieldFilter?["op"] as? String == "GREATER_THAN")
    }

    @Test("Field - greater than or equal operator")
    func fieldGreaterThanOrEqual() {
        let filter = Field("count") >= 10

        let json = filter.toJSON()
        let fieldFilter = json["fieldFilter"] as? [String: Any]
        #expect(fieldFilter?["op"] as? String == "GREATER_THAN_OR_EQUAL")
    }

    // MARK: - Field Method Tests

    @Test("Field - contains method")
    func fieldContains() {
        let filter = Field("tags").contains("swift")

        let json = filter.toJSON()
        let fieldFilter = json["fieldFilter"] as? [String: Any]
        #expect(fieldFilter?["op"] as? String == "ARRAY_CONTAINS")
    }

    @Test("Field - containsAny method")
    func fieldContainsAny() {
        let filter = Field("tags").containsAny(["swift", "ios"])

        let json = filter.toJSON()
        let fieldFilter = json["fieldFilter"] as? [String: Any]
        #expect(fieldFilter?["op"] as? String == "ARRAY_CONTAINS_ANY")
    }

    @Test("Field - in method")
    func fieldIn() {
        let filter = Field("status").in(["active", "pending"])

        let json = filter.toJSON()
        let fieldFilter = json["fieldFilter"] as? [String: Any]
        #expect(fieldFilter?["op"] as? String == "IN")
    }

    @Test("Field - notIn method")
    func fieldNotIn() {
        let filter = Field("status").notIn(["deleted", "archived"])

        let json = filter.toJSON()
        let fieldFilter = json["fieldFilter"] as? [String: Any]
        #expect(fieldFilter?["op"] as? String == "NOT_IN")
    }

    @Test("Field - isNull property")
    func fieldIsNull() {
        let filter = Field("deletedAt").isNull

        let json = filter.toJSON()
        let unaryFilter = json["unaryFilter"] as? [String: Any]
        #expect(unaryFilter?["op"] as? String == "IS_NULL")
    }

    @Test("Field - isNotNull property")
    func fieldIsNotNull() {
        let filter = Field("email").isNotNull

        let json = filter.toJSON()
        let unaryFilter = json["unaryFilter"] as? [String: Any]
        #expect(unaryFilter?["op"] as? String == "IS_NOT_NULL")
    }

    // MARK: - FilterBuilder Basic Tests

    @Test("FilterBuilder - single filter")
    func filterBuilderSingle() throws {
        let collectionPath = try CollectionPath("users")
        let collection = CollectionReference(database: database, path: collectionPath)

        struct User: Codable { let name: String }

        let query = collection.query(as: User.self)
            .filter {
                Field("status") == "active"
            }

        let structuredQuery = query.buildStructuredQuery()
        let whereClause = structuredQuery["where"] as? [String: Any]
        let fieldFilter = whereClause?["fieldFilter"] as? [String: Any]

        #expect(fieldFilter?["op"] as? String == "EQUAL")
    }

    @Test("FilterBuilder - multiple filters with explicit And")
    func filterBuilderMultipleWithExplicitAnd() throws {
        let collectionPath = try CollectionPath("users")
        let collection = CollectionReference(database: database, path: collectionPath)

        struct User: Codable { let name: String }

        let query = collection.query(as: User.self)
            .filter {
                And {
                    Field("status") == "active"
                    Field("age") >= 18
                }
            }

        let structuredQuery = query.buildStructuredQuery()
        let whereClause = structuredQuery["where"] as? [String: Any]
        let compositeFilter = whereClause?["compositeFilter"] as? [String: Any]

        #expect(compositeFilter?["op"] as? String == "AND")

        let filters = compositeFilter?["filters"] as? [[String: Any]]
        #expect(filters?.count == 2)
    }

    // MARK: - And/Or Grouping Tests

    @Test("FilterBuilder - explicit And grouping")
    func filterBuilderExplicitAnd() throws {
        let collectionPath = try CollectionPath("users")
        let collection = CollectionReference(database: database, path: collectionPath)

        struct User: Codable { let name: String }

        let query = collection.query(as: User.self)
            .filter {
                And {
                    Field("status") == "active"
                    Field("verified") == true
                }
            }

        let structuredQuery = query.buildStructuredQuery()
        let whereClause = structuredQuery["where"] as? [String: Any]
        let compositeFilter = whereClause?["compositeFilter"] as? [String: Any]

        #expect(compositeFilter?["op"] as? String == "AND")
    }

    @Test("FilterBuilder - Or grouping")
    func filterBuilderOr() throws {
        let collectionPath = try CollectionPath("users")
        let collection = CollectionReference(database: database, path: collectionPath)

        struct User: Codable { let role: String }

        let query = collection.query(as: User.self)
            .filter {
                Or {
                    Field("role") == "admin"
                    Field("role") == "moderator"
                }
            }

        let structuredQuery = query.buildStructuredQuery()
        let whereClause = structuredQuery["where"] as? [String: Any]
        let compositeFilter = whereClause?["compositeFilter"] as? [String: Any]

        #expect(compositeFilter?["op"] as? String == "OR")
    }

    @Test("FilterBuilder - nested And with Or")
    func filterBuilderNestedAndWithOr() throws {
        let collectionPath = try CollectionPath("products")
        let collection = CollectionReference(database: database, path: collectionPath)

        struct Product: Codable { let name: String }

        let query = collection.query(as: Product.self)
            .filter {
                And {
                    Field("active") == true
                    Field("stock") > 0
                    Or {
                        Field("category") == "electronics"
                        Field("featured") == true
                    }
                }
            }

        let structuredQuery = query.buildStructuredQuery()
        let whereClause = structuredQuery["where"] as? [String: Any]
        let compositeFilter = whereClause?["compositeFilter"] as? [String: Any]

        // Top level should be AND
        #expect(compositeFilter?["op"] as? String == "AND")

        let filters = compositeFilter?["filters"] as? [[String: Any]]
        #expect(filters?.count == 3)
    }

    // MARK: - Conditional Filter Tests

    @Test("FilterBuilder - conditional filter with if inside And")
    func filterBuilderConditionalIf() throws {
        let collectionPath = try CollectionPath("users")
        let collection = CollectionReference(database: database, path: collectionPath)

        struct User: Codable { let name: String }

        let includeVerified = true

        let query = collection.query(as: User.self)
            .filter {
                And {
                    Field("status") == "active"
                    if includeVerified {
                        Field("verified") == true
                    }
                }
            }

        let structuredQuery = query.buildStructuredQuery()
        let whereClause = structuredQuery["where"] as? [String: Any]
        let compositeFilter = whereClause?["compositeFilter"] as? [String: Any]

        let filters = compositeFilter?["filters"] as? [[String: Any]]
        #expect(filters?.count == 2)
    }

    @Test("FilterBuilder - conditional filter with if-else")
    func filterBuilderConditionalIfElse() throws {
        let collectionPath = try CollectionPath("users")
        let collection = CollectionReference(database: database, path: collectionPath)

        struct User: Codable { let name: String }

        let filterByRole = false

        let query = collection.query(as: User.self)
            .filter {
                if filterByRole {
                    Field("role") == "admin"
                } else {
                    Field("status") == "active"
                }
            }

        let structuredQuery = query.buildStructuredQuery()
        let whereClause = structuredQuery["where"] as? [String: Any]
        let fieldFilter = whereClause?["fieldFilter"] as? [String: Any]

        let field = fieldFilter?["field"] as? [String: Any]
        #expect(field?["fieldPath"] as? String == "status")
    }

    // MARK: - Integration with Existing API Tests

    @Test("FilterBuilder - combined with order and limit")
    func filterBuilderCombinedWithOrderLimit() throws {
        let collectionPath = try CollectionPath("products")
        let collection = CollectionReference(database: database, path: collectionPath)

        struct Product: Codable {
            let name: String
            let price: Double
        }

        let query = collection.query(as: Product.self)
            .filter {
                And {
                    Field("category") == "electronics"
                    Field("price") <= 1000.0
                }
            }
            .orderDescending(by: FieldPath("price"))
            .limit(to: 10)

        let structuredQuery = query.buildStructuredQuery()

        #expect(structuredQuery["where"] != nil)
        #expect(structuredQuery["orderBy"] != nil)
        #expect(structuredQuery["limit"] as? Int == 10)
    }

    // MARK: - FirestoreValueConvertible Tests

    @Test("FirestoreValueConvertible - String")
    func firestoreValueConvertibleString() {
        let value = "test".toFirestoreValue()
        #expect(value == .string("test"))
    }

    @Test("FirestoreValueConvertible - Int")
    func firestoreValueConvertibleInt() {
        let value = 42.toFirestoreValue()
        #expect(value == .integer(42))
    }

    @Test("FirestoreValueConvertible - Double")
    func firestoreValueConvertibleDouble() {
        let value = 3.14.toFirestoreValue()
        #expect(value == .double(3.14))
    }

    @Test("FirestoreValueConvertible - Bool")
    func firestoreValueConvertibleBool() {
        let trueValue = true.toFirestoreValue()
        let falseValue = false.toFirestoreValue()
        #expect(trueValue == .boolean(true))
        #expect(falseValue == .boolean(false))
    }

    @Test("FirestoreValueConvertible - Date")
    func firestoreValueConvertibleDate() {
        let date = Date()
        let value = date.toFirestoreValue()
        #expect(value == .timestamp(date))
    }

    @Test("FirestoreValueConvertible - Array")
    func firestoreValueConvertibleArray() {
        let array = ["a", "b", "c"]
        let value = array.toFirestoreValue()
        #expect(value == .array([.string("a"), .string("b"), .string("c")]))
    }
}
