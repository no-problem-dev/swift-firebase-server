// MARK: - Macro Declarations

/// Firestoreスキーマを定義するマクロ
///
/// このマクロを構造体に適用すると、ネストされた`@Collection`構造体から
/// コレクションアクセサを自動生成します。
///
/// ```swift
/// @FirestoreSchema
/// struct AppSchema {
///     @Collection("users")
///     struct Users {
///         struct User: Codable {
///             let name: String
///         }
///     }
/// }
///
/// // 使用例
/// let schema = AppSchema(client: firestoreClient)
/// let user = try await schema.users("userId").get(as: User.self, authorization: token)
/// ```
@attached(member, names: named(database), named(client), named(init))
@attached(memberAttribute)
@attached(extension, conformances: FirestoreSchemaProtocol, Sendable)
public macro FirestoreSchema() = #externalMacro(module: "FirestoreMacros", type: "FirestoreSchemaMacro")

/// Firestoreコレクションを定義するマクロ
///
/// `@FirestoreSchema`内で使用し、コレクションIDを指定します。
///
/// ```swift
/// @Collection("users")
/// struct Users {
///     struct User: Codable { ... }
/// }
/// ```
@attached(member, names: named(database), named(client), named(parentPath), named(init), named(callAsFunction))
@attached(extension, conformances: FirestoreCollectionProtocol, Sendable)
public macro Collection(_ collectionId: String) = #externalMacro(module: "FirestoreMacros", type: "CollectionMacro")

/// Firestoreサブコレクションを定義するマクロ
///
/// ドキュメント構造体内で使用し、サブコレクションを定義します。
///
/// ```swift
/// struct User: Codable {
///     let name: String
///
///     @SubCollection("books")
///     struct Books {
///         struct Book: Codable { ... }
///     }
/// }
/// ```
@attached(member, names: named(database), named(client), named(parentPath), named(init), named(callAsFunction))
@attached(extension, conformances: FirestoreCollectionProtocol, Sendable)
public macro SubCollection(_ collectionId: String) = #externalMacro(module: "FirestoreMacros", type: "SubCollectionMacro")
