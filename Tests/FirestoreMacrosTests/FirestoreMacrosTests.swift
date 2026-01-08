import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

#if canImport(FirestoreMacros)
import FirestoreMacros

// swiftlint:disable:next identifier_name
nonisolated(unsafe) let testMacros: [String: Macro.Type] = [
    "FirestoreSchema": FirestoreSchemaMacro.self,
    "Collection": CollectionMacro.self,
]
#endif

// MARK: - FirestoreSchema Basic Tests

@Suite("FirestoreSchema Macro")
struct FirestoreSchemaMacroTests {

    @Test("Basic schema generates client, database, and init")
    func basicSchema() throws {
        #if canImport(FirestoreMacros)
        assertMacroExpansion(
            """
            @FirestoreSchema
            struct Schema {
            }
            """,
            expandedSource: """
            struct Schema {

                public let client: FirestoreClient

                public var database: DatabasePath {
                    client.database
                }

                public init(client: FirestoreClient) {
                    self.client = client
                }
            }

            extension Schema: FirestoreSchemaProtocol {
            }
            """,
            macros: testMacros
        )
        #else
        throw TestSkipError("macros are only supported when running tests for the host platform")
        #endif
    }

    @Test("Schema must be applied to struct")
    func mustBeStruct() throws {
        #if canImport(FirestoreMacros)
        assertMacroExpansion(
            """
            @FirestoreSchema
            enum Schema {
            }
            """,
            expandedSource: """
            enum Schema {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@FirestoreSchema can only be applied to structs",
                    line: 1,
                    column: 1
                )
            ],
            macros: testMacros
        )
        #else
        throw TestSkipError("macros are only supported when running tests for the host platform")
        #endif
    }
}

// MARK: - Collection Macro Tests

@Suite("Collection Macro")
struct CollectionMacroTests {

    @Test("Top-level collection generates static path methods")
    func topLevelCollection() throws {
        #if canImport(FirestoreMacros)
        assertMacroExpansion(
            """
            @Collection("users", model: User.self)
            enum Users {
            }
            """,
            expandedSource: """
            enum Users {

                public static let collectionId: String = "users"

                public typealias Model = User

                public static var collectionPath: String {
                    collectionId
                }

                public static func documentPath(_ documentId: String) -> String {
                    collectionPath + "/" + documentId
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw TestSkipError("macros are only supported when running tests for the host platform")
        #endif
    }

    @Test("Collection with different ID")
    func collectionWithDifferentId() throws {
        #if canImport(FirestoreMacros)
        assertMacroExpansion(
            """
            @Collection("genres", model: Genre.self)
            enum Genres {
            }
            """,
            expandedSource: """
            enum Genres {

                public static let collectionId: String = "genres"

                public typealias Model = Genre

                public static var collectionPath: String {
                    collectionId
                }

                public static func documentPath(_ documentId: String) -> String {
                    collectionPath + "/" + documentId
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw TestSkipError("macros are only supported when running tests for the host platform")
        #endif
    }

    @Test("Collection requires model argument")
    func requiresModelArgument() throws {
        #if canImport(FirestoreMacros)
        assertMacroExpansion(
            """
            @Collection("users")
            enum Users {
            }
            """,
            expandedSource: """
            enum Users {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Collection requires collectionId and model arguments: @Collection(\"name\", model: Type.self)",
                    line: 1,
                    column: 1
                )
            ],
            macros: testMacros
        )
        #else
        throw TestSkipError("macros are only supported when running tests for the host platform")
        #endif
    }
}

// MARK: - Schema with Collections Tests

@Suite("Schema with Collections")
struct SchemaWithCollectionsTests {

    @Test("Schema with simple collections uses FirestoreCollection")
    func simpleCollections() throws {
        #if canImport(FirestoreMacros)
        assertMacroExpansion(
            """
            @FirestoreSchema
            struct Schema {
                @Collection("users", model: User.self)
                enum Users {
                }

                @Collection("genres", model: Genre.self)
                enum Genres {
                }
            }
            """,
            expandedSource: """
            struct Schema {
                enum Users {

                    public static let collectionId: String = "users"

                    public typealias Model = User

                    public static var collectionPath: String {
                        collectionId
                    }

                    public static func documentPath(_ documentId: String) -> String {
                        collectionPath + "/" + documentId
                    }
                }
                enum Genres {

                    public static let collectionId: String = "genres"

                    public typealias Model = Genre

                    public static var collectionPath: String {
                        collectionId
                    }

                    public static func documentPath(_ documentId: String) -> String {
                        collectionPath + "/" + documentId
                    }
                }

                public let client: FirestoreClient

                public var database: DatabasePath {
                    client.database
                }

                public init(client: FirestoreClient) {
                    self.client = client
                }

                public var users: FirestoreCollection<User> {
                    FirestoreCollection(collectionId: Users.collectionId, database: database, client: client)
                }

                public var genres: FirestoreCollection<Genre> {
                    FirestoreCollection(collectionId: Genres.collectionId, database: database, client: client)
                }
            }

            extension Schema: FirestoreSchemaProtocol {
            }
            """,
            macros: testMacros
        )
        #else
        throw TestSkipError("macros are only supported when running tests for the host platform")
        #endif
    }
}

// MARK: - Sub-collection Tests

@Suite("Sub-collection Support")
struct SubCollectionTests {

    @Test("Collection with sub-collection generates specialized types")
    func collectionWithSubCollection() throws {
        #if canImport(FirestoreMacros)
        assertMacroExpansion(
            """
            @FirestoreSchema
            struct Schema {
                @Collection("users", model: User.self)
                enum Users {
                    @Collection("books", model: Book.self)
                    enum Books {
                    }
                }
            }
            """,
            expandedSource: """
            struct Schema {
                enum Users {
                    enum Books {

                        public static let collectionId: String = "books"

                        public typealias Model = Book

                        public static func collectionPath(_ p1: String) -> String {
                            Users.documentPath(p1) + "/" + collectionId
                        }

                        public static func documentPath(_ p1: String, _ documentId: String) -> String {
                            collectionPath(p1) + "/" + documentId
                        }
                    }

                    public static let collectionId: String = "users"

                    public typealias Model = User

                    public static var collectionPath: String {
                        collectionId
                    }

                    public static func documentPath(_ documentId: String) -> String {
                        collectionPath + "/" + documentId
                    }
                }

                public let client: FirestoreClient

                public var database: DatabasePath {
                    client.database
                }

                public init(client: FirestoreClient) {
                    self.client = client
                }

                public var users: UsersCollection {
                    UsersCollection(database: database, client: client)
                }

                public struct UsersCollection: FirestoreCollectionProtocol {
                    public typealias Model = User
                    public typealias Document = UsersDocument

                    public static var collectionId: String {
                        Users.collectionId
                    }
                    public let database: DatabasePath
                    public let client: FirestoreClient


                    public var parentPath: String? {
                        nil
                    }

                    public init(database: DatabasePath, client: FirestoreClient) {
                        self.database = database
                        self.client = client
                    }

                    public func document(_ documentId: String) -> UsersDocument {
                        UsersDocument(documentId: documentId, database: database, client: client, parentPath: "users")
                    }
                }

                public struct UsersDocument: FirestoreDocumentProtocol {
                    public typealias Model = User

                    public let documentId: String
                    public let database: DatabasePath
                    public let client: FirestoreClient
                    public let parentPath: String

                    public var collectionPath: String {
                        parentPath
                    }

                    public init(documentId: String, database: DatabasePath, client: FirestoreClient, parentPath: String) {
                        self.documentId = documentId
                        self.database = database
                        self.client = client
                        self.parentPath = parentPath
                    }

                    // MARK: - Sub-collections

                    public var books: FirestoreCollection<Book> {
                        FirestoreCollection(
                            collectionId: "books",
                            database: database,
                            client: client,
                            parentPath: "\\(parentPath)/\\(documentId)"
                        )
                    }
                }
            }

            extension Schema: FirestoreSchemaProtocol {
            }
            """,
            macros: testMacros
        )
        #else
        throw TestSkipError("macros are only supported when running tests for the host platform")
        #endif
    }

    @Test("Collection with multiple sub-collections")
    func multipleSubCollections() throws {
        #if canImport(FirestoreMacros)
        assertMacroExpansion(
            """
            @FirestoreSchema
            struct Schema {
                @Collection("users", model: User.self)
                enum Users {
                    @Collection("books", model: Book.self)
                    enum Books {
                    }

                    @Collection("tags", model: Tag.self)
                    enum Tags {
                    }
                }
            }
            """,
            expandedSource: """
            struct Schema {
                enum Users {
                    enum Books {

                        public static let collectionId: String = "books"

                        public typealias Model = Book

                        public static func collectionPath(_ p1: String) -> String {
                            Users.documentPath(p1) + "/" + collectionId
                        }

                        public static func documentPath(_ p1: String, _ documentId: String) -> String {
                            collectionPath(p1) + "/" + documentId
                        }
                    }
                    enum Tags {

                        public static let collectionId: String = "tags"

                        public typealias Model = Tag

                        public static func collectionPath(_ p1: String) -> String {
                            Users.documentPath(p1) + "/" + collectionId
                        }

                        public static func documentPath(_ p1: String, _ documentId: String) -> String {
                            collectionPath(p1) + "/" + documentId
                        }
                    }

                    public static let collectionId: String = "users"

                    public typealias Model = User

                    public static var collectionPath: String {
                        collectionId
                    }

                    public static func documentPath(_ documentId: String) -> String {
                        collectionPath + "/" + documentId
                    }
                }

                public let client: FirestoreClient

                public var database: DatabasePath {
                    client.database
                }

                public init(client: FirestoreClient) {
                    self.client = client
                }

                public var users: UsersCollection {
                    UsersCollection(database: database, client: client)
                }

                public struct UsersCollection: FirestoreCollectionProtocol {
                    public typealias Model = User
                    public typealias Document = UsersDocument

                    public static var collectionId: String {
                        Users.collectionId
                    }
                    public let database: DatabasePath
                    public let client: FirestoreClient


                    public var parentPath: String? {
                        nil
                    }

                    public init(database: DatabasePath, client: FirestoreClient) {
                        self.database = database
                        self.client = client
                    }

                    public func document(_ documentId: String) -> UsersDocument {
                        UsersDocument(documentId: documentId, database: database, client: client, parentPath: "users")
                    }
                }

                public struct UsersDocument: FirestoreDocumentProtocol {
                    public typealias Model = User

                    public let documentId: String
                    public let database: DatabasePath
                    public let client: FirestoreClient
                    public let parentPath: String

                    public var collectionPath: String {
                        parentPath
                    }

                    public init(documentId: String, database: DatabasePath, client: FirestoreClient, parentPath: String) {
                        self.documentId = documentId
                        self.database = database
                        self.client = client
                        self.parentPath = parentPath
                    }

                    // MARK: - Sub-collections

                    public var books: FirestoreCollection<Book> {
                        FirestoreCollection(
                            collectionId: "books",
                            database: database,
                            client: client,
                            parentPath: "\\(parentPath)/\\(documentId)"
                        )
                    }

                    public var tags: FirestoreCollection<Tag> {
                        FirestoreCollection(
                            collectionId: "tags",
                            database: database,
                            client: client,
                            parentPath: "\\(parentPath)/\\(documentId)"
                        )
                    }
                }
            }

            extension Schema: FirestoreSchemaProtocol {
            }
            """,
            macros: testMacros
        )
        #else
        throw TestSkipError("macros are only supported when running tests for the host platform")
        #endif
    }

    @Test("Mixed simple and complex collections")
    func mixedCollections() throws {
        #if canImport(FirestoreMacros)
        assertMacroExpansion(
            """
            @FirestoreSchema
            struct Schema {
                @Collection("users", model: User.self)
                enum Users {
                    @Collection("books", model: Book.self)
                    enum Books {
                    }
                }

                @Collection("genres", model: Genre.self)
                enum Genres {
                }
            }
            """,
            expandedSource: """
            struct Schema {
                enum Users {
                    enum Books {

                        public static let collectionId: String = "books"

                        public typealias Model = Book

                        public static func collectionPath(_ p1: String) -> String {
                            Users.documentPath(p1) + "/" + collectionId
                        }

                        public static func documentPath(_ p1: String, _ documentId: String) -> String {
                            collectionPath(p1) + "/" + documentId
                        }
                    }

                    public static let collectionId: String = "users"

                    public typealias Model = User

                    public static var collectionPath: String {
                        collectionId
                    }

                    public static func documentPath(_ documentId: String) -> String {
                        collectionPath + "/" + documentId
                    }
                }
                enum Genres {

                    public static let collectionId: String = "genres"

                    public typealias Model = Genre

                    public static var collectionPath: String {
                        collectionId
                    }

                    public static func documentPath(_ documentId: String) -> String {
                        collectionPath + "/" + documentId
                    }
                }

                public let client: FirestoreClient

                public var database: DatabasePath {
                    client.database
                }

                public init(client: FirestoreClient) {
                    self.client = client
                }

                public var users: UsersCollection {
                    UsersCollection(database: database, client: client)
                }

                public var genres: FirestoreCollection<Genre> {
                    FirestoreCollection(collectionId: Genres.collectionId, database: database, client: client)
                }

                public struct UsersCollection: FirestoreCollectionProtocol {
                    public typealias Model = User
                    public typealias Document = UsersDocument

                    public static var collectionId: String {
                        Users.collectionId
                    }
                    public let database: DatabasePath
                    public let client: FirestoreClient


                    public var parentPath: String? {
                        nil
                    }

                    public init(database: DatabasePath, client: FirestoreClient) {
                        self.database = database
                        self.client = client
                    }

                    public func document(_ documentId: String) -> UsersDocument {
                        UsersDocument(documentId: documentId, database: database, client: client, parentPath: "users")
                    }
                }

                public struct UsersDocument: FirestoreDocumentProtocol {
                    public typealias Model = User

                    public let documentId: String
                    public let database: DatabasePath
                    public let client: FirestoreClient
                    public let parentPath: String

                    public var collectionPath: String {
                        parentPath
                    }

                    public init(documentId: String, database: DatabasePath, client: FirestoreClient, parentPath: String) {
                        self.documentId = documentId
                        self.database = database
                        self.client = client
                        self.parentPath = parentPath
                    }

                    // MARK: - Sub-collections

                    public var books: FirestoreCollection<Book> {
                        FirestoreCollection(
                            collectionId: "books",
                            database: database,
                            client: client,
                            parentPath: "\\(parentPath)/\\(documentId)"
                        )
                    }
                }
            }

            extension Schema: FirestoreSchemaProtocol {
            }
            """,
            macros: testMacros
        )
        #else
        throw TestSkipError("macros are only supported when running tests for the host platform")
        #endif
    }
}

// MARK: - Test Skip Error

struct TestSkipError: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }
}
