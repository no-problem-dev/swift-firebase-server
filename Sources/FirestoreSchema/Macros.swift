// MARK: - Model Protocol

/// Firestoreドキュメントモデルを表すマーカープロトコル
///
/// `@FirestoreModel`マクロを適用した構造体は自動的にこのプロトコルに準拠する。
/// `@Collection`マクロの`model:`パラメータにはこのプロトコルに準拠した型のみ指定できる。
///
/// このプロトコルは`Codable`と`Sendable`を継承しないマーカープロトコル。
/// `@FirestoreModel`マクロが`Codable`と`Sendable`を別途付与する。
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
/// Swiftプロパティ名とFirestoreフィールド名の変換方法を指定する。
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
    /// プロパティ名をそのままフィールド名として使用する。
    /// FirestoreConfiguration のキー戦略はランタイムで適用される。
    case useDefault

    /// camelCase → snake_case 変換
    ///
    /// Swiftの標準的な命名規則（camelCase）から
    /// snake_case に変換する。
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
/// `Codable`と`Sendable`への準拠を付与する。
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
@attached(member, names: named(CodingKeys), named(Fields))
@attached(extension, conformances: FirestoreModelProtocol, Codable, Sendable)
public macro FirestoreModel(
    keyStrategy: FirestoreKeyStrategy = .useDefault
) = #externalMacro(module: "FirestoreMacros", type: "FirestoreModelMacro")

/// フィールドにカスタムキー名を指定するマクロ
///
/// `@FirestoreModel`内のプロパティに適用し、
/// Firestore でのフィールド名を明示的に指定する。
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
/// そのフィールドのみに特定の変換戦略を適用する。
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
/// そのフィールドを `CodingKeys` から除外する。
/// ローカルキャッシュや計算プロパティ用のバッキングストアなど、
/// Firestoreに保存しないフィールドに使用する。
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
/// **注意**: `@FieldIgnore`を適用したプロパティにはデフォルト値が必要。
@attached(peer)
public macro FieldIgnore() = #externalMacro(module: "FirestoreMacros", type: "FieldIgnoreMacro")

// MARK: - Schema Macros

/// Firestoreスキーマを定義するマクロ
///
/// structに適用し、型安全なFirestoreアクセスを自動生成する。
/// `client`、`database`プロパティと`init(client:)`イニシャライザが生成され、
/// 各`@Collection`に対応する型付きコレクションプロパティも追加される。
///
/// ```swift
/// @FirestoreSchema
/// struct Schema {
///     @Collection("users", model: User.self)
///     enum Users {}
///
///     @Collection("genres", model: Genre.self)
///     enum Genres {}
/// }
///
/// // 使用例
/// let schema = Schema(client: firestoreClient)
/// let user = try await schema.users.document("user123").get()  // User型が推論される
/// let genres = try await schema.genres.getAll()  // [Genre]型が推論される
/// ```
@attached(member, names: named(client), named(database), named(init), arbitrary)
@attached(extension, conformances: FirestoreSchemaProtocol)
public macro FirestoreSchema() = #externalMacro(module: "FirestoreMacros", type: "FirestoreSchemaMacro")

/// Firestoreコレクションを定義するマクロ
///
/// `@FirestoreSchema` struct内のenumに適用し、コレクションパスとモデル型を自動生成する。
/// ネストされている場合は自動的にサブコレクションとして扱われる。
///
/// ```swift
/// @FirestoreSchema
/// struct Schema {
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
/// // 静的パス生成
/// Schema.Users.collectionPath                              // "users"
/// Schema.Users.documentPath("userId")                      // "users/userId"
/// Schema.Users.Model.self                                  // User.Type
/// Schema.Users.Books.collectionPath("userId")              // "users/userId/books"
/// Schema.Users.Books.Model.self                            // Book.Type
///
/// // インスタンス経由のアクセス
/// let schema = Schema(client: client)
/// let user = try await schema.users.document("userId").get()  // User型が推論される
/// ```
///
/// - Parameter collectionId: Firestoreのコレクション名
/// - Parameter model: このコレクションに格納されるモデルの型（`FirestoreModelProtocol` 準拠が必要）
@attached(member, names: named(collectionId), named(collectionPath), named(documentPath), named(Model), arbitrary)
public macro Collection<T: FirestoreModelProtocol>(_ collectionId: String, model: T.Type) = #externalMacro(module: "FirestoreMacros", type: "CollectionMacro")

