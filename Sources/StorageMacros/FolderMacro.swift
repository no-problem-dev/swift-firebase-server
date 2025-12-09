import SwiftSyntax
import SwiftSyntaxMacros

/// `@Folder`マクロの実装
///
/// このマクロは以下を生成:
/// - `static var folderName: String`
/// - `client: StorageClient`プロパティ
/// - `parentPath: String?`プロパティ
/// - `init(client:parentPath:)`イニシャライザ
/// - ネストされた`@Folder`や`@Object`へのアクセサ
public struct FolderMacro {}

// MARK: - MemberMacro

extension FolderMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw StorageMacroError.requiresStruct
        }

        // フォルダ名を取得
        guard let folderName = extractStringArgument(from: node) else {
            throw StorageMacroError.missingFolderName
        }

        var members: [DeclSyntax] = []

        // static folderName
        members.append("""
            public static let folderName: String = \(literal: folderName)
            """)

        // client プロパティ
        members.append("""
            public let client: StorageClient
            """)

        // parentPath プロパティ
        members.append("""
            public let parentPath: String?
            """)

        // イニシャライザ
        members.append("""
            public init(client: StorageClient, parentPath: String?) {
                self.client = client
                self.parentPath = parentPath
            }
            """)

        // ネストされた@Folder属性を持つ構造体のアクセサを生成
        for member in structDecl.memberBlock.members {
            guard let nestedStruct = member.decl.as(StructDeclSyntax.self) else { continue }

            for attribute in nestedStruct.attributes {
                guard let attr = attribute.as(AttributeSyntax.self),
                      let identifier = attr.attributeName.as(IdentifierTypeSyntax.self)
                else { continue }

                let structName = nestedStruct.name.text
                let accessorName = structName.lowercasedFirst()

                if identifier.name.text == "Folder" {
                    // サブフォルダアクセサを生成
                    members.append("""
                        public var \(raw: accessorName): \(raw: structName) {
                            \(raw: structName)(client: client, parentPath: path)
                        }
                        """)
                } else if identifier.name.text == "Object" {
                    // オブジェクトアクセサを生成（callAsFunctionでIDと拡張子を受け取る）
                    members.append("""
                        public func \(raw: accessorName)(_ objectId: String, _ ext: FileExtension) -> \(raw: structName) {
                            \(raw: structName)(client: client, parentPath: path, objectId: objectId, fileExtension: ext)
                        }
                        """)
                }
            }
        }

        return members
    }
}

// MARK: - MemberAttributeMacro

extension FolderMacro: MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        []
    }
}

// MARK: - ExtensionMacro

extension FolderMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let ext: DeclSyntax = """
            extension \(type.trimmed): StorageFolderProtocol, Sendable {}
            """

        guard let extensionDecl = ext.as(ExtensionDeclSyntax.self) else {
            return []
        }

        return [extensionDecl]
    }
}

// MARK: - Helpers

func extractStringArgument(from node: AttributeSyntax) -> String? {
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
          let firstArg = arguments.first,
          let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
          let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
    else {
        return nil
    }
    return segment.content.text
}
