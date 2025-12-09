// MARK: - Macro Declarations

/// Storageスキーマを定義するマクロ
///
/// このマクロを構造体に適用すると、ネストされた`@Folder`構造体から
/// フォルダアクセサを自動生成します。
///
/// ```swift
/// @StorageSchema
/// struct AppStorage {
///     @Folder("images")
///     struct Images {
///         @Folder("users")
///         struct Users {
///             @Object("profile")
///             struct Profile {}
///         }
///     }
/// }
///
/// // 使用例
/// let schema = AppStorage(client: storageClient)
/// let path = schema.images.users.profile("userId", .jpg)
/// let data = try await path.download(authorization: token)
/// ```
@attached(member, names: named(client), named(init))
@attached(memberAttribute)
@attached(extension, conformances: StorageSchemaProtocol, Sendable)
public macro StorageSchema() = #externalMacro(module: "StorageMacros", type: "StorageSchemaMacro")

/// Storageフォルダを定義するマクロ
///
/// `@StorageSchema`または別の`@Folder`内で使用し、フォルダ名を指定します。
///
/// ```swift
/// @Folder("images")
/// struct Images {
///     @Folder("users")
///     struct Users { ... }
/// }
/// ```
@attached(member, names: named(client), named(parentPath), named(init))
@attached(memberAttribute)
@attached(extension, conformances: StorageFolderProtocol, Sendable)
public macro Folder(_ folderName: String) = #externalMacro(module: "StorageMacros", type: "FolderMacro")

/// Storageオブジェクト（ファイル）を定義するマクロ
///
/// `@Folder`内で使用し、オブジェクトのベース名を指定します。
/// 生成されるcallAsFunctionでIDと拡張子を指定してパスを生成できます。
///
/// ```swift
/// @Folder("users")
/// struct Users {
///     @Object("profile")  // profile("userId", .jpg) を生成
///     struct Profile {}
/// }
///
/// // 使用例
/// let path = schema.users.profile("user123", .png)
/// // → "users/user123.png"
/// ```
@attached(member, names: named(client), named(parentPath), named(objectId), named(fileExtension), named(init))
@attached(extension, conformances: StorageObjectPathProtocol, Sendable)
public macro Object(_ baseName: String) = #externalMacro(module: "StorageMacros", type: "ObjectMacro")
