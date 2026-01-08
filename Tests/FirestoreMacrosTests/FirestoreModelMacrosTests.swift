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

                enum Fields {
                    static let id = FieldPath<User>("id")
                    static let name = FieldPath<User>("name")
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

                enum Fields {
                    static let userId = FieldPath<UserProfile>("user_id")
                    static let displayName = FieldPath<UserProfile>("display_name")
                    static let createdAt = FieldPath<UserProfile>("created_at")
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

                enum Fields {
                    static let id = FieldPath<SimpleModel>("id")
                    static let value = FieldPath<SimpleModel>("value")
                }
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

                enum Fields {
                    static let userId = FieldPath<User>("user_id")
                    static let name = FieldPath<User>("name")
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

                enum Fields {
                    static let userId = FieldPath<LegacyUser>("uid")
                    static let displayName = FieldPath<LegacyUser>("display_name")
                    static let createdAt = FieldPath<LegacyUser>("created_timestamp")
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

                enum Fields {
                    static let userId = FieldPath<MixedModel>("uid")
                    static let displayName = FieldPath<MixedModel>("display_name")
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

                enum Fields {
                    static let id = FieldPath<CachedDocument>("id")
                    static let data = FieldPath<CachedDocument>("data")
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

                enum Fields {
                    static let userId = FieldPath<UserWithCache>("user_id")
                    static let displayName = FieldPath<UserWithCache>("display_name")
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

                enum Fields {
                    static let userId = FieldPath<ComplexModel>("uid")
                    static let displayName = FieldPath<ComplexModel>("display_name")
                    static let profileImageId = FieldPath<ComplexModel>("profile_image_id")
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

                enum Fields {
                    static let simpleCase = FieldPath<SnakeCaseTest>("simple_case")
                    static let userId = FieldPath<SnakeCaseTest>("user_id")
                    static let isHTTPSEnabled = FieldPath<SnakeCaseTest>("is_https_enabled")
                    static let urlString = FieldPath<SnakeCaseTest>("url_string")
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

                enum Fields {

                }
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

                enum Fields {
                    static let fieldName = FieldPath<SingleField>("field_name")
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

                enum Fields {
                    static let userId = FieldPath<WithDefaults>("user_id")
                    static let isActive = FieldPath<WithDefaults>("is_active")
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

                enum Fields {
                    static let requiredId = FieldPath<WithOptionals>("required_id")
                    static let optionalName = FieldPath<WithOptionals>("optional_name")
                    static let optionalAge = FieldPath<WithOptionals>("optional_age")
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

                enum Fields {
                    static let userId = FieldPath<FirestoreUserProfile>("user_id")
                    static let displayName = FieldPath<FirestoreUserProfile>("display_name")
                    static let profileImageId = FieldPath<FirestoreUserProfile>("profile_image_id")
                    static let bio = FieldPath<FirestoreUserProfile>("bio")
                    static let createdAt = FieldPath<FirestoreUserProfile>("created_at")
                    static let updatedAt = FieldPath<FirestoreUserProfile>("updated_at")
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
