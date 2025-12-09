import SwiftSyntax
import SwiftSyntaxMacros

/// `@StorageSchema`マクロの実装
///
/// このマクロは以下を生成:
/// - `client: StorageClient`プロパティ
/// - `init(client: StorageClient)`イニシャライザ
/// - ネストされた`@Folder`構造体へのアクセサプロパティ
public struct StorageSchemaMacro {}

// MARK: - MemberMacro

extension StorageSchemaMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw StorageMacroError.requiresStruct
        }

        var members: [DeclSyntax] = []

        // client プロパティ
        members.append("""
            public let client: StorageClient
            """)

        // イニシャライザ
        members.append("""
            public init(client: StorageClient) {
                self.client = client
            }
            """)

        // @Folder 属性を持つネストされた構造体を検索してアクセサを生成
        for member in structDecl.memberBlock.members {
            guard let nestedStruct = member.decl.as(StructDeclSyntax.self) else { continue }

            // @Folder属性を検索
            for attribute in nestedStruct.attributes {
                guard let attr = attribute.as(AttributeSyntax.self),
                      let identifier = attr.attributeName.as(IdentifierTypeSyntax.self),
                      identifier.name.text == "Folder"
                else { continue }

                let structName = nestedStruct.name.text
                let accessorName = structName.lowercasedFirst()

                // フォルダアクセサを生成
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

extension StorageSchemaMacro: MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        // ネストされた構造体に対しては何もしない（@Folderは手動で付ける）
        []
    }
}

// MARK: - ExtensionMacro

extension StorageSchemaMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let sendableExtension: DeclSyntax = """
            extension \(type.trimmed): StorageSchemaProtocol, Sendable {}
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
