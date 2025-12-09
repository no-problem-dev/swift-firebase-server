import SwiftSyntax
import SwiftSyntaxMacros

/// `@FirestoreSchema`マクロの実装
///
/// このマクロは以下を生成:
/// - `database: DatabasePath`プロパティ
/// - `client: FirestoreClient`プロパティ
/// - `init(client: FirestoreClient)`イニシャライザ
/// - ネストされた`@Collection`構造体へのアクセサプロパティ
public struct FirestoreSchemaMacro {}

// MARK: - MemberMacro

extension FirestoreSchemaMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.requiresStruct
        }

        var members: [DeclSyntax] = []

        // database プロパティ
        members.append("""
            public let database: DatabasePath
            """)

        // client プロパティ
        members.append("""
            public let client: FirestoreClient
            """)

        // イニシャライザ
        members.append("""
            public init(client: FirestoreClient) {
                self.client = client
                self.database = client.database
            }
            """)

        // @Collection 属性を持つネストされた構造体を検索してアクセサを生成
        for member in structDecl.memberBlock.members {
            guard let nestedStruct = member.decl.as(StructDeclSyntax.self) else { continue }

            // @Collection属性を検索
            for attribute in nestedStruct.attributes {
                guard let attr = attribute.as(AttributeSyntax.self),
                      let identifier = attr.attributeName.as(IdentifierTypeSyntax.self),
                      identifier.name.text == "Collection"
                else { continue }

                let structName = nestedStruct.name.text
                let accessorName = structName.lowercasedFirst()

                // コレクションアクセサを生成
                members.append("""
                    public var \(raw: accessorName): \(raw: structName) {
                        \(raw: structName)(client: client, parentPath: nil)
                    }
                    """)
            }
        }

        return members
    }
}

// MARK: - MemberAttributeMacro

extension FirestoreSchemaMacro: MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        // ネストされた構造体に対しては何もしない（@Collectionは手動で付ける）
        []
    }
}

// MARK: - ExtensionMacro

extension FirestoreSchemaMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let sendableExtension: DeclSyntax = """
            extension \(type.trimmed): FirestoreSchemaProtocol, Sendable {}
            """

        guard let extensionDecl = sendableExtension.as(ExtensionDeclSyntax.self) else {
            return []
        }

        return [extensionDecl]
    }
}

// MARK: - Helpers

extension String {
    func lowercasedFirst() -> String {
        guard let first = self.first else { return self }
        return first.lowercased() + dropFirst()
    }
}
