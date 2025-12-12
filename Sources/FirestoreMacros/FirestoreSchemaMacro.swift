import SwiftSyntax
import SwiftSyntaxMacros

/// `@FirestoreSchema`マクロの実装
///
/// structに適用し、以下を自動生成します:
/// - `init(client:)` イニシャライザ
/// - `client` プロパティ
/// - `database` プロパティ
/// - 各コレクションのインスタンスプロパティ（型付きコレクション）
///
/// 生成例:
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
/// // 展開後
/// struct Schema: FirestoreSchemaProtocol {
///     public let client: FirestoreClient
///     public var database: DatabasePath { client.database }
///
///     public init(client: FirestoreClient) {
///         self.client = client
///     }
///
///     public var users: FirestoreCollection<User> {
///         FirestoreCollection(collectionId: Users.collectionId, database: database, client: client)
///     }
///
///     public var genres: FirestoreCollection<Genre> {
///         FirestoreCollection(collectionId: Genres.collectionId, database: database, client: client)
///     }
/// }
///
/// // 使用例
/// let schema = Schema(client: firestoreClient)
/// let user = try await schema.users.document("user123").get()  // User型が推論される
/// ```
public struct FirestoreSchemaMacro: MemberMacro, ExtensionMacro {

    // MARK: - MemberMacro

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // structであることを確認
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.message("@FirestoreSchema can only be applied to structs")
        }

        // @Collectionが付いたネストされたenumを見つける
        let collections = findCollectionEnums(in: structDecl)

        // コレクションプロパティを生成
        let collectionProperties = collections.map { collection in
            let propertyName = collection.enumName.lowercasedFirst()
            return """
                public var \(propertyName): FirestoreCollection<\(collection.modelType)> {
                    FirestoreCollection(collectionId: \(collection.enumName).collectionId, database: database, client: client)
                }
            """
        }.joined(separator: "\n\n")

        // プロパティとイニシャライザを直接生成
        let clientProperty: DeclSyntax = "public let client: FirestoreClient"

        let databaseProperty: DeclSyntax = """
            public var database: DatabasePath { client.database }
            """

        let initializer: DeclSyntax = """
            public init(client: FirestoreClient) {
                self.client = client
            }
            """

        var result: [DeclSyntax] = [
            clientProperty,
            databaseProperty,
            initializer,
        ]

        // コレクションプロパティがあれば追加
        if !collectionProperties.isEmpty {
            let properties: DeclSyntax = "\(raw: collectionProperties)"
            result.append(properties)
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

    // MARK: - Helpers

    private struct CollectionInfo {
        let enumName: String
        let collectionId: String
        let modelType: String
    }

    private static func findCollectionEnums(in structDecl: StructDeclSyntax) -> [CollectionInfo] {
        var collections: [CollectionInfo] = []

        for member in structDecl.memberBlock.members {
            guard let nestedEnum = member.decl.as(EnumDeclSyntax.self) else {
                continue
            }

            // @Collectionアトリビュートを探す
            for attribute in nestedEnum.attributes {
                guard let attr = attribute.as(AttributeSyntax.self),
                      let identifier = attr.attributeName.as(IdentifierTypeSyntax.self),
                      identifier.name.text == "Collection",
                      let args = extractCollectionArguments(from: attr) else {
                    continue
                }

                collections.append(CollectionInfo(
                    enumName: nestedEnum.name.text,
                    collectionId: args.collectionId,
                    modelType: args.modelType
                ))
            }
        }

        return collections
    }

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
