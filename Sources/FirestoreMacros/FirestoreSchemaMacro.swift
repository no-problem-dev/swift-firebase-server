import SwiftSyntax
import SwiftSyntaxMacros

/// `@FirestoreSchema`マクロの実装
///
/// structに適用し、以下を自動生成します:
/// - `init(client:)` イニシャライザ
/// - `client` プロパティ
/// - `database` プロパティ
/// - 各コレクションのインスタンスプロパティ
/// - サブコレクションを持つコレクション用の専用Collection/Document型
///
/// 生成例:
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
/// // 展開後:
/// // - Schema.users: UsersCollection（専用型、サブコレクションあり）
/// // - Schema.genres: FirestoreCollection<Genre>（汎用型、サブコレクションなし）
/// // - UsersCollection.document(_:) -> UsersDocument
/// // - UsersDocument.books: FirestoreCollection<Book>
///
/// // 使用例:
/// let schema = Schema(client: firestoreClient)
/// let user = try await schema.users.document("userId").get()
/// let books = schema.users.document("userId").books  // サブコレクションへのアクセス
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

        // コレクション構造を再帰的にパース
        let rootCollections = parseCollections(in: structDecl)

        var result: [DeclSyntax] = []

        // 基本プロパティ
        result.append("public let client: FirestoreClient")
        result.append("public var database: DatabasePath { client.database }")
        result.append("""
            public init(client: FirestoreClient) {
                self.client = client
            }
            """)

        // トップレベルコレクションプロパティを生成
        for collection in rootCollections {
            let propertyName = collection.enumName.lowercasedFirst()

            if collection.subCollections.isEmpty {
                // サブコレクションなし → 汎用FirestoreCollectionを使用
                result.append("""
                    public var \(raw: propertyName): FirestoreCollection<\(raw: collection.modelType)> {
                        FirestoreCollection(collectionId: \(raw: collection.enumName).collectionId, database: database, client: client)
                    }
                    """)
            } else {
                // サブコレクションあり → 専用Collection型を使用
                let collectionTypeName = "\(collection.enumName)Collection"
                result.append("""
                    public var \(raw: propertyName): \(raw: collectionTypeName) {
                        \(raw: collectionTypeName)(database: database, client: client)
                    }
                    """)
            }
        }

        // サブコレクションを持つコレクション用の専用型を生成
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

    /// サブコレクションを持つコレクション用の専用Collection型とDocument型を生成
    private static func generateCollectionTypes(
        for collection: CollectionNode,
        parentPath: String?
    ) -> [DeclSyntax] {
        var result: [DeclSyntax] = []

        let collectionTypeName = "\(collection.enumName)Collection"
        let documentTypeName = "\(collection.enumName)Document"

        // parentPath計算用のコード生成
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

        // Collection型を生成
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

        // Document型を生成（サブコレクションアクセサ付き）
        let subCollectionAccessors = collection.subCollections.map { sub in
            let accessorName = sub.enumName.lowercasedFirst()
            let subCollectionId = sub.collectionId

            if sub.subCollections.isEmpty {
                // サブコレクションなし → 汎用FirestoreCollection
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
                // さらにサブコレクションあり → 専用Collection型
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

        // ネストされたサブコレクションに対しても再帰的に型を生成
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

    /// 2階層以上ネストされたサブコレクション用の型を生成
    private static func generateNestedCollectionTypes(
        for collection: CollectionNode,
        ancestorCollectionId: String
    ) -> [DeclSyntax] {
        var result: [DeclSyntax] = []

        let collectionTypeName = "\(collection.enumName)Collection"
        let documentTypeName = "\(collection.enumName)Document"

        // Collection型（parentDocumentIdとgrandParentPathを持つ）
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

        // Document型
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

    /// コレクション構造を表すノード
    private struct CollectionNode {
        let enumName: String
        let collectionId: String
        let modelType: String
        var subCollections: [CollectionNode]
    }

    /// structから再帰的にコレクション構造をパース
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

    /// enumから再帰的にコレクションノードをパース
    private static func parseCollectionEnum(_ enumDecl: EnumDeclSyntax) -> CollectionNode? {
        // @Collectionアトリビュートを探す
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

        // サブコレクションを再帰的にパース
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

    /// @Collection属性から引数を抽出
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
