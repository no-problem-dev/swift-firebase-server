import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(FirestoreMacros)
import FirestoreMacros

// swiftlint:disable:next identifier_name
nonisolated(unsafe) let testMacros: [String: Macro.Type] = [
    "FirestoreSchema": FirestoreSchemaMacro.self,
    "Collection": CollectionMacro.self,
    "SubCollection": SubCollectionMacro.self,
]
#endif

final class FirestoreMacrosTests: XCTestCase {

    // MARK: - FirestoreSchema Tests

    func testFirestoreSchemaBasic() throws {
        #if canImport(FirestoreMacros)
        assertMacroExpansion(
            """
            @FirestoreSchema
            struct AppSchema {
            }
            """,
            expandedSource: """
            struct AppSchema {

                public let database: DatabasePath

                public let client: FirestoreClient

                public init(client: FirestoreClient) {
                    self.client = client
                    self.database = client.database
                }
            }

            extension AppSchema: FirestoreSchemaProtocol, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testFirestoreSchemaWithCollection() throws {
        #if canImport(FirestoreMacros)
        assertMacroExpansion(
            """
            @FirestoreSchema
            struct AppSchema {
                @Collection("users")
                struct Users {
                }
            }
            """,
            expandedSource: """
            struct AppSchema {
                struct Users {

                    public static let collectionId: String = "users"

                    public let database: DatabasePath

                    public let client: FirestoreClient

                    public let parentPath: String?

                    public init(client: FirestoreClient, parentPath: String?) {
                        self.client = client
                        self.database = client.database
                        self.parentPath = parentPath
                    }

                    public struct UsersDocument: FirestoreDocumentProtocol, Sendable {
                        public let documentId: String
                        public let database: DatabasePath
                        public let client: FirestoreClient
                        public let collectionPath: String

                        public init(documentId: String, database: DatabasePath, client: FirestoreClient, collectionPath: String) {
                            self.documentId = documentId
                            self.database = database
                            self.client = client
                            self.collectionPath = collectionPath
                        }
                    }

                    public func callAsFunction(_ documentId: String) -> UsersDocument {
                        let path: String
                        if let parentPath = parentPath {
                            path = "\\(parentPath)/\\(Self.collectionId)"
                        } else {
                            path = Self.collectionId
                        }
                        return UsersDocument(
                            documentId: documentId,
                            database: database,
                            client: client,
                            collectionPath: path
                        )
                    }
                }

                public let database: DatabasePath

                public let client: FirestoreClient

                public init(client: FirestoreClient) {
                    self.client = client
                    self.database = client.database
                }

                public var users: Users {
                    Users(client: client, parentPath: nil)
                }
            }

            extension AppSchema.Users: FirestoreCollectionProtocol, Sendable {
            }

            extension AppSchema: FirestoreSchemaProtocol, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Collection Tests

    func testCollectionMacro() throws {
        #if canImport(FirestoreMacros)
        assertMacroExpansion(
            """
            @Collection("users")
            struct Users {
            }
            """,
            expandedSource: """
            struct Users {

                public static let collectionId: String = "users"

                public let database: DatabasePath

                public let client: FirestoreClient

                public let parentPath: String?

                public init(client: FirestoreClient, parentPath: String?) {
                    self.client = client
                    self.database = client.database
                    self.parentPath = parentPath
                }

                public struct UsersDocument: FirestoreDocumentProtocol, Sendable {
                    public let documentId: String
                    public let database: DatabasePath
                    public let client: FirestoreClient
                    public let collectionPath: String

                    public init(documentId: String, database: DatabasePath, client: FirestoreClient, collectionPath: String) {
                        self.documentId = documentId
                        self.database = database
                        self.client = client
                        self.collectionPath = collectionPath
                    }
                }

                public func callAsFunction(_ documentId: String) -> UsersDocument {
                    let path: String
                    if let parentPath = parentPath {
                        path = "\\(parentPath)/\\(Self.collectionId)"
                    } else {
                        path = Self.collectionId
                    }
                    return UsersDocument(
                        documentId: documentId,
                        database: database,
                        client: client,
                        collectionPath: path
                    )
                }
            }

            extension Users: FirestoreCollectionProtocol, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - SubCollection Tests

    func testSubCollectionMacro() throws {
        #if canImport(FirestoreMacros)
        assertMacroExpansion(
            """
            @SubCollection("books")
            struct Books {
            }
            """,
            expandedSource: """
            struct Books {

                public static let collectionId: String = "books"

                public let database: DatabasePath

                public let client: FirestoreClient

                public let parentPath: String?

                public init(client: FirestoreClient, parentPath: String?) {
                    self.client = client
                    self.database = client.database
                    self.parentPath = parentPath
                }

                public struct BooksDocument: FirestoreDocumentProtocol, Sendable {
                    public let documentId: String
                    public let database: DatabasePath
                    public let client: FirestoreClient
                    public let collectionPath: String

                    public init(documentId: String, database: DatabasePath, client: FirestoreClient, collectionPath: String) {
                        self.documentId = documentId
                        self.database = database
                        self.client = client
                        self.collectionPath = collectionPath
                    }
                }

                public func callAsFunction(_ documentId: String) -> BooksDocument {
                    let path: String
                    if let parentPath = parentPath {
                        path = "\\(parentPath)/\\(Self.collectionId)"
                    } else {
                        path = Self.collectionId
                    }
                    return BooksDocument(
                        documentId: documentId,
                        database: database,
                        client: client,
                        collectionPath: path
                    )
                }
            }

            extension Books: FirestoreCollectionProtocol, Sendable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
