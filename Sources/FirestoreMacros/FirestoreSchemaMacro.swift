import SwiftSyntax
import SwiftSyntaxMacros

/// The expansion behind `@FirestoreSchema`.
///
/// Applied to a struct, it generates:
/// - an `init(client:)`
/// - a `client` property
/// - a `database` property forwarded from the client
/// - one instance property per top-level collection
/// - dedicated collection and document types for the collections that have sub-collections
///
/// Nested enums without a `@Collection` attribute are ignored rather than rejected. Applying the
/// macro to anything but a struct throws "@FirestoreSchema can only be applied to structs".
///
/// Expansion:
/// ```swift
/// @FirestoreSchema
/// struct Schema {
///     @Collection("users", model: User.self)
///     enum Users {
///         @Collection("books", model: Book.self)
///         enum Books {}
///     }
///
///     @Collection("genres", model: Genre.self)
///     enum Genres {}
/// }
///
/// // expands to:
/// // - Schema.users: UsersCollection (dedicated type, because it has sub-collections)
/// // - Schema.genres: FirestoreCollection<Genre> (generic type, no sub-collections)
/// // - UsersCollection.document(_:) -> UsersDocument
/// // - UsersDocument.books: FirestoreCollection<Book>
///
/// // usage:
/// let schema = Schema(client: firestoreClient)
/// let user = try await schema.users.document("userId").get()
/// let books = schema.users.document("userId").books  // reaching the sub-collection
/// ```
public struct FirestoreSchemaMacro: MemberMacro, ExtensionMacro {

    // MARK: - MemberMacro

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.message("@FirestoreSchema can only be applied to structs")
        }

        // Parse the collection tree recursively
        let rootCollections = parseCollections(in: structDecl)

        var result: [DeclSyntax] = []

        // Core members every schema gets
        result.append("public let client: FirestoreClient")
        result.append("public var database: DatabasePath { client.database }")
        result.append("""
            public init(client: FirestoreClient) {
                self.client = client
            }
            """)

        // One property per top-level collection
        for collection in rootCollections {
            let propertyName = collection.enumName.lowercasedFirst()

            if collection.subCollections.isEmpty {
                // No sub-collections: the generic FirestoreCollection is enough
                result.append("""
                    public var \(raw: propertyName): FirestoreCollection<\(raw: collection.modelType)> {
                        FirestoreCollection(collectionId: \(raw: collection.enumName).collectionId, database: database, client: client)
                    }
                    """)
            } else {
                // Has sub-collections: hand out the dedicated collection type
                let collectionTypeName = "\(collection.enumName)Collection"
                result.append("""
                    public var \(raw: propertyName): \(raw: collectionTypeName) {
                        \(raw: collectionTypeName)(database: database, client: client)
                    }
                    """)
            }
        }

        // Emit the dedicated types for the collections that have sub-collections
        for collection in rootCollections where !collection.subCollections.isEmpty {
            let generatedTypes = generateCollectionTypes(for: collection, parentPath: nil)
            for typeDecl in generatedTypes {
                result.append(typeDecl)
            }
        }

        return result
    }

    // MARK: - ExtensionMacro

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let ext: DeclSyntax = """
            extension \(type.trimmed): FirestoreSchemaProtocol {}
            """
        return [ext.cast(ExtensionDeclSyntax.self)]
    }

    // MARK: - Collection Type Generation

    /// Generates the dedicated collection and document types for a collection that has
    /// sub-collections, with one sub-collection accessor per child on the document type.
    private static func generateCollectionTypes(
        for collection: CollectionNode,
        parentPath: String?
    ) -> [DeclSyntax] {
        var result: [DeclSyntax] = []

        let collectionTypeName = "\(collection.enumName)Collection"
        let documentTypeName = "\(collection.enumName)Document"

        // Source for the parentPath expression
        let parentPathExpr: String
        if let parentPath = parentPath {
            parentPathExpr = "\"\(parentPath)/\\(parentDocumentId)\""
        } else {
            parentPathExpr = "nil"
        }

        let parentPathProperty: String
        let initParams: String
        let initAssignments: String
        let documentInitCall: String

        if parentPath != nil {
            parentPathProperty = "public var parentPath: String? { \(parentPathExpr) }"
            initParams = "database: DatabasePath, client: FirestoreClient, parentDocumentId: String"
            initAssignments = """
                self.database = database
                        self.client = client
                        self.parentDocumentId = parentDocumentId
                """
            documentInitCall = "\(documentTypeName)(documentId: documentId, database: database, client: client, parentPath: parentPath ?? \"\(collection.collectionId)\")"
        } else {
            parentPathProperty = "public var parentPath: String? { nil }"
            initParams = "database: DatabasePath, client: FirestoreClient"
            initAssignments = """
                self.database = database
                        self.client = client
                """
            documentInitCall = "\(documentTypeName)(documentId: documentId, database: database, client: client, parentPath: \"\(collection.collectionId)\")"
        }

        let parentDocumentIdProperty = parentPath != nil ? "public let parentDocumentId: String" : ""

        // The collection type
        result.append("""
            public struct \(raw: collectionTypeName): FirestoreCollectionProtocol {
                public typealias Model = \(raw: collection.modelType)
                public typealias Document = \(raw: documentTypeName)

                public static var collectionId: String { \(raw: collection.enumName).collectionId }
                public let database: DatabasePath
                public let client: FirestoreClient
                \(raw: parentDocumentIdProperty)

                \(raw: parentPathProperty)

                public init(\(raw: initParams)) {
                    \(raw: initAssignments)
                }

                public func document(_ documentId: String) -> \(raw: documentTypeName) {
                    \(raw: documentInitCall)
                }
            }
            """)

        // The document type, carrying one accessor per sub-collection
        let subCollectionAccessors = collection.subCollections.map { sub in
            let accessorName = sub.enumName.lowercasedFirst()
            let subCollectionId = sub.collectionId

            if sub.subCollections.isEmpty {
                // Leaf sub-collection: the generic FirestoreCollection
                return """
                    public var \(accessorName): FirestoreCollection<\(sub.modelType)> {
                            FirestoreCollection(
                                collectionId: "\(subCollectionId)",
                                database: database,
                                client: client,
                                parentPath: "\\(parentPath)/\\(documentId)"
                            )
                        }
                    """
            } else {
                // Has sub-collections of its own: the dedicated collection type
                let subCollectionTypeName = "\(sub.enumName)Collection"
                return """
                    public var \(accessorName): \(subCollectionTypeName) {
                            \(subCollectionTypeName)(
                                database: database,
                                client: client,
                                parentDocumentId: documentId,
                                grandParentPath: parentPath
                            )
                        }
                    """
            }
        }.joined(separator: "\n\n")

        result.append("""
            public struct \(raw: documentTypeName): FirestoreDocumentProtocol {
                public typealias Model = \(raw: collection.modelType)

                public let documentId: String
                public let database: DatabasePath
                public let client: FirestoreClient
                public let parentPath: String

                public var collectionPath: String { parentPath }

                public init(documentId: String, database: DatabasePath, client: FirestoreClient, parentPath: String) {
                    self.documentId = documentId
                    self.database = database
                    self.client = client
                    self.parentPath = parentPath
                }

                // MARK: - Sub-collections

                \(raw: subCollectionAccessors)
            }
            """)

        // Recurse into the sub-collections that have children of their own
        for sub in collection.subCollections where !sub.subCollections.isEmpty {
            let subParentPath = collection.collectionId
            let nestedTypes = generateNestedCollectionTypes(
                for: sub,
                ancestorCollectionId: subParentPath
            )
            result.append(contentsOf: nestedTypes)
        }

        return result
    }

    /// Generates the types for a sub-collection nested two or more levels deep, which need a
    /// grandparent path as well as the parent document ID.
    ///
    /// This level does not recurse: its document type exposes each child as a generic
    /// `FirestoreCollection`, so a collection nested below that gets no accessor.
    private static func generateNestedCollectionTypes(
        for collection: CollectionNode,
        ancestorCollectionId: String
    ) -> [DeclSyntax] {
        var result: [DeclSyntax] = []

        let collectionTypeName = "\(collection.enumName)Collection"
        let documentTypeName = "\(collection.enumName)Document"

        // The collection type, which carries both parentDocumentId and grandParentPath
        result.append("""
            public struct \(raw: collectionTypeName): FirestoreCollectionProtocol {
                public typealias Model = \(raw: collection.modelType)
                public typealias Document = \(raw: documentTypeName)

                public static var collectionId: String { "\(raw: collection.collectionId)" }
                public let database: DatabasePath
                public let client: FirestoreClient
                public let parentDocumentId: String
                public let grandParentPath: String

                public var parentPath: String? { "\\(grandParentPath)/\\(parentDocumentId)" }

                public init(database: DatabasePath, client: FirestoreClient, parentDocumentId: String, grandParentPath: String) {
                    self.database = database
                    self.client = client
                    self.parentDocumentId = parentDocumentId
                    self.grandParentPath = grandParentPath
                }

                public func document(_ documentId: String) -> \(raw: documentTypeName) {
                    \(raw: documentTypeName)(
                        documentId: documentId,
                        database: database,
                        client: client,
                        parentPath: "\\(grandParentPath)/\\(parentDocumentId)/\(raw: collection.collectionId)"
                    )
                }
            }
            """)

        // The document type
        let subCollectionAccessors = collection.subCollections.map { sub in
            let accessorName = sub.enumName.lowercasedFirst()
            return """
                public var \(accessorName): FirestoreCollection<\(sub.modelType)> {
                        FirestoreCollection(
                            collectionId: "\(sub.collectionId)",
                            database: database,
                            client: client,
                            parentPath: "\\(parentPath)/\\(documentId)"
                        )
                    }
                """
        }.joined(separator: "\n\n")

        result.append("""
            public struct \(raw: documentTypeName): FirestoreDocumentProtocol {
                public typealias Model = \(raw: collection.modelType)

                public let documentId: String
                public let database: DatabasePath
                public let client: FirestoreClient
                public let parentPath: String

                public var collectionPath: String { parentPath }

                public init(documentId: String, database: DatabasePath, client: FirestoreClient, parentPath: String) {
                    self.documentId = documentId
                    self.database = database
                    self.client = client
                    self.parentPath = parentPath
                }

                \(raw: subCollectionAccessors.isEmpty ? "// No sub-collections" : "// MARK: - Sub-collections\n\n\(subCollectionAccessors)")
            }
            """)

        return result
    }

    // MARK: - Collection Parsing

    /// One collection in the parsed schema tree, with its children attached.
    private struct CollectionNode {
        let enumName: String
        let collectionId: String
        let modelType: String
        var subCollections: [CollectionNode]
    }

    /// Reads the schema tree out of the struct's nested enums, skipping members that are not
    /// enums carrying `@Collection`.
    private static func parseCollections(in structDecl: StructDeclSyntax) -> [CollectionNode] {
        var collections: [CollectionNode] = []

        for member in structDecl.memberBlock.members {
            guard let nestedEnum = member.decl.as(EnumDeclSyntax.self) else {
                continue
            }

            if let node = parseCollectionEnum(nestedEnum) {
                collections.append(node)
            }
        }

        return collections
    }

    /// Builds a node from one enum and its nested enums.
    ///
    /// Returns `nil` when the enum has no usable `@Collection`, which also prunes everything
    /// nested inside it.
    private static func parseCollectionEnum(_ enumDecl: EnumDeclSyntax) -> CollectionNode? {
        // Look for the @Collection attribute
        var collectionId: String?
        var modelType: String?

        for attribute in enumDecl.attributes {
            guard let attr = attribute.as(AttributeSyntax.self),
                  let identifier = attr.attributeName.as(IdentifierTypeSyntax.self),
                  identifier.name.text == "Collection",
                  let args = extractCollectionArguments(from: attr) else {
                continue
            }

            collectionId = args.collectionId
            modelType = args.modelType
            break
        }

        guard let cid = collectionId, let mt = modelType else {
            return nil
        }

        // Parse the sub-collections recursively
        var subCollections: [CollectionNode] = []
        for member in enumDecl.memberBlock.members {
            guard let nestedEnum = member.decl.as(EnumDeclSyntax.self) else {
                continue
            }

            if let subNode = parseCollectionEnum(nestedEnum) {
                subCollections.append(subNode)
            }
        }

        return CollectionNode(
            enumName: enumDecl.name.text,
            collectionId: cid,
            modelType: mt,
            subCollections: subCollections
        )
    }

    /// Pulls the collection ID and model type out of a `@Collection` attribute.
    ///
    /// Returns `nil` unless the ID is a plain string literal and the model is written as
    /// `Type.self`, so an interpolated ID or a metatype expression is treated as no attribute
    /// at all.
    private static func extractCollectionArguments(from attr: AttributeSyntax) -> (collectionId: String, modelType: String)? {
        guard let arguments = attr.arguments?.as(LabeledExprListSyntax.self) else {
            return nil
        }

        var collectionId: String?
        var modelType: String?

        for arg in arguments {
            if arg.label == nil {
                if let stringLiteral = arg.expression.as(StringLiteralExprSyntax.self),
                   let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
                    collectionId = segment.content.text
                }
            } else if arg.label?.text == "model" {
                if let memberAccess = arg.expression.as(MemberAccessExprSyntax.self),
                   memberAccess.declName.baseName.text == "self",
                   let base = memberAccess.base {
                    modelType = base.description.trimmingCharacters(in: .whitespaces)
                }
            }
        }

        guard let cid = collectionId, let mt = modelType else {
            return nil
        }

        return (cid, mt)
    }
}

// MARK: - String Extension

extension String {
    func lowercasedFirst() -> String {
        guard let first = self.first else { return self }
        return first.lowercased() + self.dropFirst()
    }
}
