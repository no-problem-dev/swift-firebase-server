import SwiftSyntax
import SwiftSyntaxMacros

/// `@Object`マクロの実装
///
/// このマクロは以下を生成:
/// - `static var baseName: String`
/// - `client: StorageClient`プロパティ
/// - `parentPath: String`プロパティ
/// - `objectId: String`プロパティ
/// - `fileExtension: FileExtension`プロパティ
/// - `init(client:parentPath:objectId:fileExtension:)`イニシャライザ
public struct ObjectMacro {}

// MARK: - MemberMacro

extension ObjectMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.as(StructDeclSyntax.self) != nil else {
            throw StorageMacroError.requiresStruct
        }

        // ベース名を取得
        guard let baseName = extractStringArgument(from: node) else {
            throw StorageMacroError.missingObjectBaseName
        }

        var members: [DeclSyntax] = []

        // static baseName
        members.append("""
            public static let baseName: String = \(literal: baseName)
            """)

        // client プロパティ
        members.append("""
            public let client: StorageClient
            """)

        // parentPath プロパティ
        members.append("""
            public let parentPath: String
            """)

        // objectId プロパティ
        members.append("""
            public let objectId: String
            """)

        // fileExtension プロパティ
        members.append("""
            public let fileExtension: FileExtension
            """)

        // イニシャライザ
        members.append("""
            public init(client: StorageClient, parentPath: String, objectId: String, fileExtension: FileExtension) {
                self.client = client
                self.parentPath = parentPath
                self.objectId = objectId
                self.fileExtension = fileExtension
            }
            """)

        return members
    }
}

// MARK: - ExtensionMacro

extension ObjectMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let ext: DeclSyntax = """
            extension \(type.trimmed): StorageObjectPathProtocol, Sendable {}
            """

        guard let extensionDecl = ext.as(ExtensionDeclSyntax.self) else {
            return []
        }

        return [extensionDecl]
    }
}
