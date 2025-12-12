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
]
#endif

final class FirestoreMacrosTests: XCTestCase {

    // MARK: - FirestoreSchema Tests

    func testFirestoreSchemaBasic() throws {
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
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Collection Tests (Top-level)

    func testCollectionMacroTopLevel() throws {
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
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testCollectionMacroWithDifferentId() throws {
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
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Full Schema Tests

    func testFullSchemaDefinition() throws {
        #if canImport(FirestoreMacros)
        assertMacroExpansion(
            """
            @FirestoreSchema
            enum Schema {
                @Collection("users", model: User.self)
                enum Users {
                }

                @Collection("genres", model: Genre.self)
                enum Genres {
                }
            }
            """,
            expandedSource: """
            enum Schema {
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
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Error Tests

    func testCollectionMacroMissingModelError() throws {
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
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
