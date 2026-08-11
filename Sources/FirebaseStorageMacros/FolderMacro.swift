import SwiftSyntax
import SwiftSyntaxMacros

/// The implementation of `@Folder`.
///
/// Adds to the annotated struct:
/// - `static let folderName: String`, holding the macro's argument
/// - `client: StorageClient` and `parentPath: String?` properties
/// - `init(client:parentPath:)`
/// - one accessor per nested struct marked `@Folder` (a property) or `@Object` (a method taking an
///   object ID and a `FileExtension`), each named after the struct with a lowercased first letter
/// - conformance to `StorageFolderProtocol` and `Sendable`
///
/// Rejects anything that is not a struct with `StorageMacroError.requiresStruct`, and an argument
/// that is not a plain string literal with `.missingFolderName`.
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

        // Read the folder name from the attribute argument.
        guard let folderName = extractStringArgument(from: node) else {
            throw StorageMacroError.missingFolderName
        }

        var members: [DeclSyntax] = []

        // static folderName
        members.append("""
            public static let folderName: String = \(literal: folderName)
            """)

        // client property
        members.append("""
            public let client: StorageClient
            """)

        // parentPath property
        members.append("""
            public let parentPath: String?
            """)

        // Initializer
        members.append("""
            public init(client: StorageClient, parentPath: String?) {
                self.client = client
                self.parentPath = parentPath
            }
            """)

        // Generate an accessor for every nested struct carrying @Folder or @Object.
        for member in structDecl.memberBlock.members {
            guard let nestedStruct = member.decl.as(StructDeclSyntax.self) else { continue }

            for attribute in nestedStruct.attributes {
                guard let attr = attribute.as(AttributeSyntax.self),
                      let identifier = attr.attributeName.as(IdentifierTypeSyntax.self)
                else { continue }

                let structName = nestedStruct.name.text
                let accessorName = structName.lowercasedFirst()

                if identifier.name.text == "Folder" {
                    // A nested folder becomes a property that inherits this folder's path.
                    members.append("""
                        public var \(raw: accessorName): \(raw: structName) {
                            \(raw: structName)(client: client, parentPath: path)
                        }
                        """)
                } else if identifier.name.text == "Object" {
                    // A nested object becomes a method taking the object ID and extension.
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
    /// Adds no attributes to nested members.
    ///
    /// Nested structs must carry `@Folder` or `@Object` themselves; the macro reads those
    /// attributes but never writes them.
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

/// Reads the first argument of an attribute as a literal string.
///
/// Returns `nil` unless the argument is a string literal whose first segment is plain text, so an
/// interpolated or concatenated name is rejected rather than partially read. Callers turn that
/// `nil` into a `StorageMacroError`.
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
