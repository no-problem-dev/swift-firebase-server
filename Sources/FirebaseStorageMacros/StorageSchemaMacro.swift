import SwiftSyntax
import SwiftSyntaxMacros

/// The implementation of `@StorageSchema`.
///
/// Adds to the annotated struct:
/// - a `client: StorageClient` property
/// - `init(client: StorageClient)`
/// - one accessor property per nested struct marked `@Folder`, named after the struct with a
///   lowercased first letter and built with a `nil` parent path so the folder sits at the bucket root
/// - conformance to `StorageSchemaProtocol` and `Sendable`
///
/// Rejects anything that is not a struct with `StorageMacroError.requiresStruct`.
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

        // client property
        members.append("""
            public let client: StorageClient
            """)

        // Initializer
        members.append("""
            public init(client: StorageClient) {
                self.client = client
            }
            """)

        // Generate an accessor for every nested struct marked @Folder.
        for member in structDecl.memberBlock.members {
            guard let nestedStruct = member.decl.as(StructDeclSyntax.self) else { continue }

            // Look for the @Folder attribute.
            for attribute in nestedStruct.attributes {
                guard let attr = attribute.as(AttributeSyntax.self),
                      let identifier = attr.attributeName.as(IdentifierTypeSyntax.self),
                      identifier.name.text == "Folder"
                else { continue }

                let structName = nestedStruct.name.text
                let accessorName = structName.lowercasedFirst()

                // Root-level folder: no parent path.
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
        // Nothing is added to nested members; @Folder is written by hand.
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
