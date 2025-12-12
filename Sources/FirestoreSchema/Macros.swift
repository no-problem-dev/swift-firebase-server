// MARK: - Model Protocol

/// Firestoreドキュメントモデルを表すマーカープロトコル
///
/// `@FirestoreModel`マクロを適用した構造体は自動的にこのプロトコルに準拠します。
/// `@Collection`マクロの`model:`パラメータにはこのプロトコルに準拠した型のみ指定できます。
///
/// このプロトコルは`Codable`と`Sendable`を継承しないマーカープロトコルです。
/// `@FirestoreModel`マクロが`Codable`と`Sendable`を別途付与します。
///
/// ```swift
/// @FirestoreModel  // 自動的にFirestoreModelProtocol, Codable, Sendableに準拠
/// struct User {
///     let id: String
///     let name: String
/// }
///
/// @Collection("users", model: User.self)  // OK: UserはFirestoreModelProtocolに準拠
/// enum Users {}
///
/// struct PlainStruct: Codable, Sendable { let id: String }
/// @Collection("items", model: PlainStruct.self)  // コンパイルエラー: FirestoreModelProtocolに準拠していない
/// enum Items {}
/// ```
public protocol FirestoreModelProtocol: Sendable {}

// MARK: - Key Strategy

/// Firestoreフィールドのキー変換戦略
///
/// `@FirestoreModel`や`@Field`マクロで使用し、
/// Swiftプロパティ名とFirestoreフィールド名の変換方法を指定します。
///
/// ```swift
/// @FirestoreModel(keyStrategy: .snakeCase)
/// struct UserProfile {
///     let userId: String      // → user_id
///     let displayName: String // → display_name
/// }
/// ```
public enum FirestoreKeyStrategy: Sendable {
    /// デフォルト（変換なし）
    ///
    /// プロパティ名をそのままフィールド名として使用します。
    /// FirestoreConfigurationのKeyStrategyがあれば、それがランタイムで適用されます。
    case useDefault

    /// camelCase → snake_case 変換
    ///
    /// Swiftの標準的な命名規則（camelCase）から
    /// snake_caseに変換します。
    ///
    /// 例:
    /// - `userId` → `user_id`
    /// - `createdAt` → `created_at`
    /// - `isActive` → `is_active`
    case snakeCase
}

// MARK: - Model Macros

/// Firestoreドキュメントモデルを定義するマクロ
///
/// このマクロを構造体に適用すると、`CodingKeys`を自動生成し、
/// `Codable`と`Sendable`への準拠を追加します。
///
/// ```swift
/// @FirestoreModel(keyStrategy: .snakeCase)
/// struct UserProfile {
///     let userId: String        // → user_id
///     let displayName: String   // → display_name
///
///     @Field("uid")             // カスタムキー
///     let uniqueId: String      // → uid
///
///     @FieldIgnore              // Firestoreに保存しない
///     var localCache: String?
/// }
/// ```
///
/// - Parameter keyStrategy: デフォルトのキー変換戦略。省略時は`.useDefault`
@attached(member, names: named(CodingKeys))
@attached(extension, conformances: FirestoreModelProtocol, Codable, Sendable)
public macro FirestoreModel(
    keyStrategy: FirestoreKeyStrategy = .useDefault
) = #externalMacro(module: "FirestoreMacros", type: "FirestoreModelMacro")

/// フィールドにカスタムキー名を指定するマクロ
///
/// `@FirestoreModel`内のプロパティに適用し、
/// Firestoreでのフィールド名を明示的に指定します。
///
/// ```swift
/// @FirestoreModel
/// struct User {
///     @Field("user_id")
///     let userId: String  // → user_id
/// }
/// ```
///
/// - Parameter key: Firestoreでのフィールド名
@attached(peer)
public macro Field(_ key: String) = #externalMacro(module: "FirestoreMacros", type: "FieldMacro")

/// フィールドにキー変換戦略を指定するマクロ
///
/// `@FirestoreModel`内のプロパティに適用し、
/// そのフィールドのみに特定の変換戦略を適用します。
///
/// ```swift
/// @FirestoreModel  // デフォルトは useDefault
/// struct User {
///     @Field(strategy: .snakeCase)
///     let displayName: String  // → display_name（このフィールドのみsnake_case）
///
///     let normalField: String  // → normalField（変換なし）
/// }
/// ```
///
/// - Parameter strategy: このフィールドに適用するキー変換戦略
@attached(peer)
public macro Field(strategy: FirestoreKeyStrategy) = #externalMacro(module: "FirestoreMacros", type: "FieldStrategyMacro")

/// フィールドをFirestoreエンコード/デコードから除外するマクロ
///
/// `@FirestoreModel`内のプロパティに適用し、
/// そのフィールドをCodingKeysから除外します。
/// ローカルキャッシュや計算プロパティ用のバッキングストアなど、
/// Firestoreに保存しないフィールドに使用します。
///
/// ```swift
/// @FirestoreModel
/// struct CachedDocument {
///     let id: String
///     let data: String
///
///     @FieldIgnore
///     var localTimestamp: Date?  // Firestoreに保存しない
/// }
/// ```
///
/// **注意**: `@FieldIgnore`を適用したプロパティにはデフォルト値が必要です。
@attached(peer)
public macro FieldIgnore() = #externalMacro(module: "FirestoreMacros", type: "FieldIgnoreMacro")

// MARK: - Schema Macros

/// Firestoreスキーマを定義するマクロ
///
/// enumに適用し、ネストされた`@Collection` enumからパスアクセサを自動生成します。
///
/// ```swift
/// @FirestoreSchema
/// enum Schema {
///     @Collection("users")
///     enum users {
///         @SubCollection("books")
///         enum books
///     }
///
///     @Collection("genres")
///     enum genres
/// }
///
/// // 使用例
/// Schema.users.collectionPath                    // "users"
/// Schema.users.documentPath("userId")            // "users/userId"
/// Schema.users.books.collectionPath("userId")    // "users/userId/books"
/// Schema.users.books.documentPath("userId", "bookId") // "users/userId/books/bookId"
/// ```
@attached(member, names: arbitrary)
public macro FirestoreSchema() = #externalMacro(module: "FirestoreMacros", type: "FirestoreSchemaMacro")

/// Firestoreコレクションを定義するマクロ
///
/// `@FirestoreSchema` enum内のenumに適用し、コレクションパスとモデル型を自動生成します。
/// ネストされている場合は自動的にサブコレクションとして扱われます。
///
/// ```swift
/// @FirestoreSchema
/// enum Schema {
///     @Collection("users", model: User.self)
///     enum Users {
///         @Collection("books", model: Book.self)
///         enum Books {
///             @Collection("chats", model: Chat.self)
///             enum Chats {}
///         }
///     }
/// }
///
/// // 使用例
/// Schema.Users.collectionPath                              // "users"
/// Schema.Users.documentPath("userId")                      // "users/userId"
/// Schema.Users.Model.self                                  // User.Type
/// Schema.Users.Books.collectionPath("userId")              // "users/userId/books"
/// Schema.Users.Books.Model.self                            // Book.Type
/// ```
///
/// - Parameter collectionId: Firestoreのコレクション名
/// - Parameter model: このコレクションに格納されるモデルの型（`FirestoreModelProtocol`に準拠している必要があります）
@attached(member, names: named(collectionId), named(collectionPath), named(documentPath), named(Model), arbitrary)
public macro Collection<T: FirestoreModelProtocol>(_ collectionId: String, model: T.Type) = #externalMacro(module: "FirestoreMacros", type: "CollectionMacro")

