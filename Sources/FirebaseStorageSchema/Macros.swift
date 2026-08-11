// MARK: - Macro Declarations

/// Declares the root of a typed storage path schema.
///
/// Expands to a `client` property, an `init(client:)`, and one accessor per nested `@Folder`
/// struct, and conforms the type to `StorageSchemaProtocol` and `Sendable`. Each accessor is named
/// after its struct with a lowercased first letter and hands the folder a `nil` parent, which puts
/// that folder at the root of the bucket.
///
/// Only nested structs marked `@Folder` get an accessor — the macro does not apply `@Folder` for
/// you. Applying it to anything other than a struct fails expansion.
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
/// // Usage
/// let schema = AppStorage(client: storageClient)
/// let path = schema.images.users.profile("userId", .jpg)  // "images/users/userId.jpg"
/// let data = try await path.download()
/// ```
@attached(member, names: named(client), named(init))
@attached(memberAttribute)
@attached(extension, conformances: StorageSchemaProtocol, Sendable)
public macro StorageSchema() = #externalMacro(module: "FirebaseStorageMacros", type: "StorageSchemaMacro")

/// Declares one path segment inside a storage schema.
///
/// Use it on a struct nested in `@StorageSchema` or in another `@Folder`. It expands to
/// `static let folderName`, a `client` and `parentPath` pair, `init(client:parentPath:)`, and one
/// accessor per nested declaration: a nested `@Folder` becomes a property, and a nested `@Object`
/// becomes a method taking an object ID and a `FileExtension`. The type gains
/// `StorageFolderProtocol` and `Sendable` conformance, and its `path` joins the parent path and
/// this segment with `/`.
///
/// The folder name must be a plain string literal — an interpolated one is rejected, as is
/// applying the macro to anything other than a struct.
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
public macro Folder(_ folderName: String) = #externalMacro(module: "FirebaseStorageMacros", type: "FolderMacro")

/// Declares a file at the end of a storage path.
///
/// Use it on a struct nested in a `@Folder`. It expands to `static let baseName`, the
/// `client` / `parentPath` / `objectId` / `fileExtension` properties, a matching initializer, and
/// `StorageObjectPathProtocol` and `Sendable` conformance — which is what gives the type its
/// `upload`, `download`, `delete`, `getMetadata`, and `publicURL` members.
///
/// The enclosing `@Folder` generates the accessor, naming it after the struct with a lowercased
/// first letter. The path it builds is `"{folder path}/{objectId}{extension}"`, so the base name
/// argument is recorded on the type but never appears in the path.
///
/// The base name must be a plain string literal, and the macro only applies to a struct.
///
/// ```swift
/// @Folder("users")
/// struct Users {
///     @Object("profile")  // generates users.profile("userId", .jpg)
///     struct Profile {}
/// }
///
/// // Usage
/// let path = schema.users.profile("user123", .png)
/// // → "users/user123.png"
/// ```
@attached(member, names: named(client), named(parentPath), named(objectId), named(fileExtension), named(init))
@attached(extension, conformances: StorageObjectPathProtocol, Sendable)
public macro Object(_ baseName: String) = #externalMacro(module: "FirebaseStorageMacros", type: "ObjectMacro")
