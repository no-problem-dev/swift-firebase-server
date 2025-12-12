import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(FirestoreMacros)
import FirestoreMacros

// swiftlint:disable:next identifier_name
nonisolated(unsafe) let modelMacros: [String: Macro.Type] = [
    "FirestoreModel": FirestoreModelMacro.self,
    "Field": FieldMacro.self,
    "FieldIgnore": FieldIgnoreMacro.self,
]
#endif

final class FirestoreModelMacrosTests: XCTestCase {

    // MARK: - FirestoreModel Basic Tests

    func testFirestoreModelBasicNoTransformation() throws {
        #if canImport(FirestoreMacros)
        assertMacroExpansion(
            """
            @FirestoreModel
            struct User {
                let id: String
                let name: String
            }
            """,
            expandedSource: """
            struct User {
                let id: String
                let name: String
            }

            extension User: FirestoreModelProtocol, Codable {
            }
            """,
            macros: modelMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testFirestoreModelWithSnakeCaseStrategy() throws {
        #if canImport(FirestoreMacros)
        assertMacroExpansion(
            """
            @FirestoreModel(keyStrategy: .snakeCase)
            struct UserProfile {
                let userId: String
                let displayName: String
                let createdAt: Int
            }
            """,
            expandedSource: """
            struct UserProfile {
                let userId: String
                let displayName: String
                let createdAt: Int

                enum CodingKeys: String, CodingKey {
                    case userId = "user_id"
                    case displayName = "display_name"
                    case createdAt = "created_at"
                }
            }

            extension UserProfile: FirestoreModelProtocol, Codable {
            }
            """,
            macros: modelMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testFirestoreModelWithUseDefaultStrategy() throws {
        #if canImport(FirestoreMacros)
        assertMacroExpansion(
            """
            @FirestoreModel(keyStrategy: .useDefault)
            struct SimpleModel {
                let id: String
                let value: Int
            }
            """,
            expandedSource: """
            struct SimpleModel {
                let id: String
                let value: Int
            }

            extension SimpleModel: FirestoreModelProtocol, Codable {
            }
            """,
            macros: modelMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - @Field Tests

    func testFieldWithCustomKey() throws {
        #if canImport(FirestoreMacros)
        assertMacroExpansion(
            """
            @FirestoreModel
            struct User {
                @Field("user_id")
                let userId: String
                let name: String
            }
            """,
            expandedSource: """
            struct User {
                let userId: String
                let name: String

                enum CodingKeys: String, CodingKey {
                    case userId = "user_id"
                    case name
                }
            }

            extension User: FirestoreModelProtocol, Codable {
            }
            """,
            macros: modelMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testFieldWithMultipleCustomKeys() throws {
        #if canImport(FirestoreMacros)
        assertMacroExpansion(
            """
            @FirestoreModel
            struct LegacyUser {
                @Field("uid")
                let userId: String
                @Field("display_name")
                let displayName: String
                @Field("created_timestamp")
                let createdAt: Int
            }
            """,
            expandedSource: """
            struct LegacyUser {
                let userId: String
                let displayName: String
                let createdAt: Int

                enum CodingKeys: String, CodingKey {
                    case userId = "uid"
                    case displayName = "display_name"
                    case createdAt = "created_timestamp"
                }
            }

            extension LegacyUser: FirestoreModelProtocol, Codable {
            }
            """,
            macros: modelMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testFieldOverridesModelStrategy() throws {
        #if canImport(FirestoreMacros)
        assertMacroExpansion(
            """
            @FirestoreModel(keyStrategy: .snakeCase)
            struct MixedModel {
                @Field("uid")
                let userId: String
                let displayName: String
            }
            """,
            expandedSource: """
            struct MixedModel {
                let userId: String
                let displayName: String

                enum CodingKeys: String, CodingKey {
                    case userId = "uid"
                    case displayName = "display_name"
                }
            }

            extension MixedModel: FirestoreModelProtocol, Codable {
            }
            """,
            macros: modelMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - @FieldIgnore Tests

    func testFieldIgnore() throws {
        #if canImport(FirestoreMacros)
        assertMacroExpansion(
            """
            @FirestoreModel
            struct CachedDocument {
                let id: String
                let data: String
                @FieldIgnore
                var localCache: String?
            }
            """,
            expandedSource: """
            struct CachedDocument {
                let id: String
                let data: String
                var localCache: String?

                enum CodingKeys: String, CodingKey {
                    case id
                    case data
                }
            }

            extension CachedDocument: FirestoreModelProtocol, Codable {
            }
            """,
            macros: modelMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testFieldIgnoreWithSnakeCaseStrategy() throws {
        #if canImport(FirestoreMacros)
        assertMacroExpansion(
            """
            @FirestoreModel(keyStrategy: .snakeCase)
            struct UserWithCache {
                let userId: String
                let displayName: String
                @FieldIgnore
                var temporaryState: Int?
            }
            """,
            expandedSource: """
            struct UserWithCache {
                let userId: String
                let displayName: String
                var temporaryState: Int?

                enum CodingKeys: String, CodingKey {
                    case userId = "user_id"
                    case displayName = "display_name"
                }
            }

            extension UserWithCache: FirestoreModelProtocol, Codable {
            }
            """,
            macros: modelMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Combined Tests

    func testAllFeaturesCombiined() throws {
        #if canImport(FirestoreMacros)
        assertMacroExpansion(
            """
            @FirestoreModel(keyStrategy: .snakeCase)
            struct ComplexModel {
                @Field("uid")
                let userId: String
                let displayName: String
                let profileImageId: String?
                @FieldIgnore
                var localTimestamp: Int?
            }
            """,
            expandedSource: """
            struct ComplexModel {
                let userId: String
                let displayName: String
                let profileImageId: String?
                var localTimestamp: Int?

                enum CodingKeys: String, CodingKey {
                    case userId = "uid"
                    case displayName = "display_name"
                    case profileImageId = "profile_image_id"
                }
            }

            extension ComplexModel: FirestoreModelProtocol, Codable {
            }
            """,
            macros: modelMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Snake Case Conversion Tests

    func testSnakeCaseConversionVariousPatterns() throws {
        #if canImport(FirestoreMacros)
        assertMacroExpansion(
            """
            @FirestoreModel(keyStrategy: .snakeCase)
            struct SnakeCaseTest {
                let simpleCase: String
                let userId: String
                let isHTTPSEnabled: Bool
                let urlString: String
            }
            """,
            expandedSource: """
            struct SnakeCaseTest {
                let simpleCase: String
                let userId: String
                let isHTTPSEnabled: Bool
                let urlString: String

                enum CodingKeys: String, CodingKey {
                    case simpleCase = "simple_case"
                    case userId = "user_id"
                    case isHTTPSEnabled = "is_https_enabled"
                    case urlString = "url_string"
                }
            }

            extension SnakeCaseTest: FirestoreModelProtocol, Codable {
            }
            """,
            macros: modelMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Edge Cases

    func testEmptyStruct() throws {
        #if canImport(FirestoreMacros)
        assertMacroExpansion(
            """
            @FirestoreModel
            struct EmptyModel {
            }
            """,
            expandedSource: """
            struct EmptyModel {
            }

            extension EmptyModel: FirestoreModelProtocol, Codable {
            }
            """,
            macros: modelMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testSingleProperty() throws {
        #if canImport(FirestoreMacros)
        assertMacroExpansion(
            """
            @FirestoreModel(keyStrategy: .snakeCase)
            struct SingleField {
                let fieldName: String
            }
            """,
            expandedSource: """
            struct SingleField {
                let fieldName: String

                enum CodingKeys: String, CodingKey {
                    case fieldName = "field_name"
                }
            }

            extension SingleField: FirestoreModelProtocol, Codable {
            }
            """,
            macros: modelMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testPropertyWithDefaultValue() throws {
        #if canImport(FirestoreMacros)
        assertMacroExpansion(
            """
            @FirestoreModel(keyStrategy: .snakeCase)
            struct WithDefaults {
                let userId: String
                var isActive: Bool = true
            }
            """,
            expandedSource: """
            struct WithDefaults {
                let userId: String
                var isActive: Bool = true

                enum CodingKeys: String, CodingKey {
                    case userId = "user_id"
                    case isActive = "is_active"
                }
            }

            extension WithDefaults: FirestoreModelProtocol, Codable {
            }
            """,
            macros: modelMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testOptionalProperties() throws {
        #if canImport(FirestoreMacros)
        assertMacroExpansion(
            """
            @FirestoreModel(keyStrategy: .snakeCase)
            struct WithOptionals {
                let requiredId: String
                let optionalName: String?
                var optionalAge: Int?
            }
            """,
            expandedSource: """
            struct WithOptionals {
                let requiredId: String
                let optionalName: String?
                var optionalAge: Int?

                enum CodingKeys: String, CodingKey {
                    case requiredId = "required_id"
                    case optionalName = "optional_name"
                    case optionalAge = "optional_age"
                }
            }

            extension WithOptionals: FirestoreModelProtocol, Codable {
            }
            """,
            macros: modelMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Real-World Use Case

    func testRealisticUserProfile() throws {
        #if canImport(FirestoreMacros)
        assertMacroExpansion(
            """
            @FirestoreModel(keyStrategy: .snakeCase)
            struct FirestoreUserProfile {
                let userId: String
                let displayName: String
                let profileImageId: String?
                let bio: String?
                let createdAt: Int
                let updatedAt: Int
            }
            """,
            expandedSource: """
            struct FirestoreUserProfile {
                let userId: String
                let displayName: String
                let profileImageId: String?
                let bio: String?
                let createdAt: Int
                let updatedAt: Int

                enum CodingKeys: String, CodingKey {
                    case userId = "user_id"
                    case displayName = "display_name"
                    case profileImageId = "profile_image_id"
                    case bio
                    case createdAt = "created_at"
                    case updatedAt = "updated_at"
                }
            }

            extension FirestoreUserProfile: FirestoreModelProtocol, Codable {
            }
            """,
            macros: modelMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
