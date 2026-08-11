import SwiftSyntax
import SwiftSyntaxMacros

/// The implementation of `@Object`.
///
/// Adds to the annotated struct:
/// - `static let baseName: String`, holding the macro's argument
/// - a `client: StorageClient` property
/// - `parentPath: String`, `objectId: String`, and `fileExtension: FileExtension` properties
/// - `init(client:parentPath:objectId:fileExtension:)`
/// - conformance to `StorageObjectPathProtocol` and `Sendable`
///
/// Rejects anything that is not a struct with `StorageMacroError.requiresStruct`, and an argument
/// that is not a plain string literal with `.missingObjectBaseName`.
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

        // Read the base name from the attribute argument.
        guard let baseName = extractStringArgument(from: node) else {
            throw StorageMacroError.missingObjectBaseName
        }

        var members: [DeclSyntax] = []

        // static baseName
        members.append("""
            public static let baseName: String = \(literal: baseName)
            """)

        // client property
        members.append("""
            public let client: StorageClient
            """)

        // parentPath property
        members.append("""
            public let parentPath: String
            """)

        // objectId property
        members.append("""
            public let objectId: String
            """)

        // fileExtension property
        members.append("""
            public let fileExtension: FileExtension
            """)

        // Initializer
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
