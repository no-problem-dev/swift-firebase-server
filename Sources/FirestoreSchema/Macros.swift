// MARK: - Model Protocol

/// A marker for the model type a Firestore collection stores.
///
/// A struct annotated with `@FirestoreModel` conforms automatically. `@Collection` accepts only
/// conforming types for `model:`, so handing it a plain `Codable` struct is a compile error —
/// that is the whole point of the marker.
///
/// The protocol refines `Sendable`, so conforming types are `Sendable` too. `@FirestoreModel`
/// adds `Codable` in the same generated extension, which is what keeps the compiler's
/// `Codable` synthesis available.
///
/// ```swift
/// @FirestoreModel  // conforms to FirestoreModelProtocol and Codable automatically
/// struct User {
///     let id: String
///     let name: String
/// }
///
/// @Collection("users", model: User.self)  // OK: User conforms to FirestoreModelProtocol
/// enum Users {}
///
/// struct PlainStruct: Codable, Sendable { let id: String }
/// @Collection("items", model: PlainStruct.self)  // compile error: does not conform to FirestoreModelProtocol
/// enum Items {}
/// ```
public protocol FirestoreModelProtocol: Sendable {}

// MARK: - Key Strategy

/// How a Swift property name is turned into a Firestore field name.
///
/// Passed to `@FirestoreModel` for a whole model, or to `@Field(strategy:)` for one property.
/// The macro resolves the strategy at compile time and bakes the result into `CodingKeys`.
///
/// ```swift
/// @FirestoreModel(keyStrategy: .snakeCase)
/// struct UserProfile {
///     let userId: String      // → user_id
///     let displayName: String // → display_name
/// }
/// ```
public enum FirestoreKeyStrategy: Sendable {
    /// Keeps the property name as the field name.
    ///
    /// Nothing is rewritten at compile time, so the key strategy configured on the client's
    /// `FirestoreConfiguration` is what decides the stored field name at encode and decode time.
    case useDefault

    /// Converts camelCase property names to snake_case field names.
    ///
    /// The converted name is written into `CodingKeys`, and the client's key encoding strategy
    /// then runs on top of it when writing. For example:
    /// - `userId` → `user_id`
    /// - `createdAt` → `created_at`
    /// - `isActive` → `is_active`
    case snakeCase
}

// MARK: - Model Macros

/// Generates the Firestore field mapping for a document model.
///
/// Applied to a struct, the macro generates a `Fields` enum of `FieldPath` constants for
/// type-safe queries, and adds conformance to `FirestoreModelProtocol` and `Codable` in one
/// extension. It generates `CodingKeys` only when at least one stored property needs a key
/// other than its own name — a `@Field("key")`, a `.snakeCase` strategy, or a `@FieldIgnore`.
/// Applying it to anything other than a struct fails with
/// "@FirestoreModel can only be applied to struct declarations".
///
/// Per property, the key comes from the first of these that is present: `@Field("key")`, then
/// `@Field(strategy:)`, then this `keyStrategy:`. Whatever the macro settles on is still passed
/// through the key encoding strategy of the client's `FirestoreConfiguration` when writing.
///
/// ```swift
/// @FirestoreModel(keyStrategy: .snakeCase)
/// struct UserProfile {
///     let userId: String        // → user_id
///     let displayName: String   // → display_name
///
///     @Field("uid")             // custom key
///     let uniqueId: String      // → uid
///
///     @FieldIgnore              // not stored in Firestore
///     var localCache: String?
/// }
/// ```
///
/// - Parameter keyStrategy: The conversion applied to properties that carry no `@Field` of their own.
///
/// - Note: Only stored properties are mapped, and `CodingKeys` and `Fields` are generated
///   without an access modifier, so they stay internal even on a public model.
@attached(member, names: named(CodingKeys), named(Fields))
@attached(extension, conformances: FirestoreModelProtocol, Codable, Sendable)
public macro FirestoreModel(
    keyStrategy: FirestoreKeyStrategy = .useDefault
) = #externalMacro(module: "FirestoreMacros", type: "FirestoreModelMacro")

/// Names the Firestore field for one property explicitly.
///
/// Apply it to a property of a `@FirestoreModel` struct. The key wins over both
/// `@Field(strategy:)` and the model's `keyStrategy:`. The macro emits no code of its own —
/// `@FirestoreModel` reads the attribute and writes the key into `CodingKeys` and `Fields`.
/// Applying it to something that is not a property, or passing anything but a string literal,
/// fails with an "Invalid argument" diagnostic.
///
/// ```swift
/// @FirestoreModel
/// struct User {
///     @Field("user_id")
///     let userId: String  // → user_id
/// }
/// ```
///
/// - Parameter key: The field name to use in Firestore.
@attached(peer)
public macro Field(_ key: String) = #externalMacro(module: "FirestoreMacros", type: "FieldMacro")

/// Applies a key conversion to one property only.
///
/// Overrides the model's `keyStrategy:` for that property, and is in turn overridden by
/// `@Field("key")` on the same property. Like `@Field(_:)` it emits no code; `@FirestoreModel`
/// reads it. Applying it to something that is not a property, or omitting the `strategy:`
/// label, fails with an "Invalid argument" diagnostic.
///
/// ```swift
/// @FirestoreModel  // the model default is useDefault
/// struct User {
///     @Field(strategy: .snakeCase)
///     let displayName: String  // → display_name (this property only)
///
///     let normalField: String  // → normalField (unconverted)
/// }
/// ```
///
/// - Parameter strategy: The conversion to apply to this property.
@attached(peer)
public macro Field(strategy: FirestoreKeyStrategy) = #externalMacro(module: "FirestoreMacros", type: "FieldStrategyMacro")

/// Keeps a property out of the Firestore mapping.
///
/// The property is left out of both the generated `CodingKeys` and `Fields`, so it is neither
/// encoded nor decoded nor usable in a query. Use it for local caches and backing stores.
/// Its presence alone is enough to make `@FirestoreModel` generate `CodingKeys`.
///
/// ```swift
/// @FirestoreModel
/// struct CachedDocument {
///     let id: String
///     let data: String
///
///     @FieldIgnore
///     var localTimestamp: Date?  // not stored in Firestore
/// }
/// ```
///
/// - Important: The property needs a default value or an optional type. Because it has no
///   `CodingKeys` case, the synthesized `init(from:)` has nothing to initialize it with.
@attached(peer)
public macro FieldIgnore() = #externalMacro(module: "FirestoreMacros", type: "FieldIgnoreMacro")

// MARK: - Schema Macros

/// Turns a struct of `@Collection` enums into typed Firestore accessors.
///
/// The macro generates a `client` property, a `database` property forwarded from the client,
/// an `init(client:)`, conformance to `FirestoreSchemaProtocol`, and one property per top-level
/// `@Collection` enum. A collection with no sub-collections becomes a
/// `FirestoreCollection<Model>`; a collection that has sub-collections gets a dedicated
/// collection and document type so the sub-collections are reachable from a document.
/// Applying it to anything other than a struct fails with
/// "@FirestoreSchema can only be applied to structs".
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
/// // usage
/// let schema = Schema(client: firestoreClient)
/// let user = try await schema.users.document("user123").get()  // inferred as User
/// let (genres, nextPage) = try await schema.genres.getAll()  // genres is [Genre]
/// ```
///
/// - Note: Typed accessors are generated three collection levels deep. At the third level the
///   accessor is a plain `FirestoreCollection`, whose documents expose no sub-collections of
///   their own, so a fourth level has to be addressed through the client directly.
@attached(member, names: named(client), named(database), named(init), arbitrary)
@attached(extension, conformances: FirestoreSchemaProtocol)
public macro FirestoreSchema() = #externalMacro(module: "FirestoreMacros", type: "FirestoreSchemaMacro")

/// Declares a Firestore collection on an enum inside a `@FirestoreSchema` struct.
///
/// The macro generates `collectionId`, `typealias Model`, and the path builders. A top-level
/// enum gets `collectionPath` and `documentPath(_:)`. An enum nested inside another
/// `@Collection` enum is treated as a sub-collection: its path builders take one document ID
/// per ancestor, outermost first. Applying it to anything other than an enum fails with
/// "@Collection can only be applied to enums", and leaving out either argument fails with
/// "@Collection requires collectionId and model arguments".
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
/// // static path building
/// Schema.Users.collectionPath                              // "users"
/// Schema.Users.documentPath("userId")                      // "users/userId"
/// Schema.Users.Model.self                                  // User.Type
/// Schema.Users.Books.collectionPath("userId")              // "users/userId/books"
/// Schema.Users.Books.Model.self                            // Book.Type
///
/// // access through a schema instance
/// let schema = Schema(client: client)
/// let user = try await schema.users.document("userId").get()  // inferred as User
/// ```
///
/// - Parameters:
///   - collectionId: The collection name in Firestore.
///   - model: The document type stored in the collection. It must conform to
///     `FirestoreModelProtocol`, which `@FirestoreModel` provides.
@attached(member, names: named(collectionId), named(collectionPath), named(documentPath), named(Model), arbitrary)
public macro Collection<T: FirestoreModelProtocol>(_ collectionId: String, model: T.Type) = #externalMacro(module: "FirestoreMacros", type: "CollectionMacro")

