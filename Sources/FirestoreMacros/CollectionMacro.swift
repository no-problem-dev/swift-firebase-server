import SwiftSyntax
import SwiftSyntaxMacros

/// The expansion behind `@Collection`.
///
/// Applied to an enum, it generates `collectionId`, `typealias Model`, and the path builders.
/// Nesting is read from the lexical context, so an enum inside another `@Collection` enum
/// becomes a sub-collection whose path builders take one document ID per ancestor, outermost
/// first. A non-enum declaration throws "@Collection can only be applied to enums", and a
/// missing or unreadable argument throws "@Collection requires collectionId and model
/// arguments".
///
/// Expansion:
/// ```swift
/// @FirestoreSchema
/// struct Schema {
///     @Collection("users", model: User.self)
///     enum Users {
///         // collectionId = "users"
///         // collectionPath = "users"
///         // documentPath(userId) = "users/{userId}"
///         // typealias Model = User
///
///         @Collection("books", model: Book.self)
///         enum Books {
///             // collectionPath(userId) = "users/{userId}/books"
///             // documentPath(userId, bookId) = "users/{userId}/books/{bookId}"
///             // typealias Model = Book
///         }
///     }
/// }
/// ```
public struct CollectionMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Reject anything that is not an enum
        guard declaration.as(EnumDeclSyntax.self) != nil else {
            throw MacroError.message("@Collection can only be applied to enums")
        }

        // Read the arguments
        guard let args = extractArguments(from: node) else {
            throw MacroError.message("@Collection requires collectionId and model arguments: @Collection(\"name\", model: Type.self)")
        }

        // Enclosing collections, nearest parent first
        let parentCollections = findParentCollections(in: context)
        let depth = parentCollections.count

        var members: [DeclSyntax] = []

        // static let collectionId
        members.append("""
            public static let collectionId: String = \(literal: args.collectionId)
            """)

        // typealias Model = T
        members.append("""
            public typealias Model = \(raw: args.modelType)
            """)

        if depth == 0 {
            // A root collection
            members.append(contentsOf: generateTopLevelMembers())
        } else {
            // A sub-collection: one path parameter per ancestor
            members.append(contentsOf: generateSubCollectionMembers(
                parentCollections: parentCollections
            ))
        }

        return members
    }

    // MARK: - Top-level Collection Members

    private static func generateTopLevelMembers() -> [DeclSyntax] {
        return [
            """
            public static var collectionPath: String {
                collectionId
            }
            """,
            """
            public static func documentPath(_ documentId: String) -> String {
                collectionPath + "/" + documentId
            }
            """
        ]
    }

    // MARK: - Sub-collection Members

    private static func generateSubCollectionMembers(
        parentCollections: [String]
    ) -> [DeclSyntax] {
        let depth = parentCollections.count

        // Parameter names p1, p2, ... hold the ancestors' document IDs, outermost first
        let paramNames = (1...depth).map { "p\($0)" }
        let paramDecls = paramNames.map { "_ \($0): String" }.joined(separator: ", ")

        // Delegate to the nearest parent's documentPath, which unwinds the rest of the chain
        // e.g. at depth 2 this calls Books.documentPath(p1, p2)
        let immediateParent = parentCollections[0]
        let parentArgs = paramNames.joined(separator: ", ")

        return [
            """
            public static func collectionPath(\(raw: paramDecls)) -> String {
                \(raw: immediateParent).documentPath(\(raw: parentArgs)) + "/" + collectionId
            }
            """,
            """
            public static func documentPath(\(raw: paramDecls), _ documentId: String) -> String {
                collectionPath(\(raw: parentArgs)) + "/" + documentId
            }
            """
        ]
    }

    // MARK: - Helpers

    private static func extractArguments(from node: AttributeSyntax) -> (collectionId: String, modelType: String)? {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
            return nil
        }

        var collectionId: String?
        var modelType: String?

        for arg in arguments {
            if arg.label == nil {
                // The first, unlabeled argument is the collection ID
                if let stringLiteral = arg.expression.as(StringLiteralExprSyntax.self),
                   let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
                    collectionId = segment.content.text
                }
            } else if arg.label?.text == "model" {
                // model: Type.self
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

    /// Walks the lexical context for enclosing enums that carry `@Collection`.
    ///
    /// The result runs from the nearest parent outwards, e.g. `["Books", "Users"]`, and its
    /// count is the nesting depth. Enclosing enums without the attribute are not counted, so
    /// they do not add a path parameter.
    private static func findParentCollections(in context: some MacroExpansionContext) -> [String] {
        var parents: [String] = []

        for lexicalContext in context.lexicalContext {
            guard let enumDecl = lexicalContext.as(EnumDeclSyntax.self) else {
                continue
            }

            // Does this enum carry the @Collection attribute?
            let hasCollectionAttribute = enumDecl.attributes.contains { attr in
                guard let attribute = attr.as(AttributeSyntax.self),
                      let identifier = attribute.attributeName.as(IdentifierTypeSyntax.self) else {
                    return false
                }
                return identifier.name.text == "Collection"
            }

            if hasCollectionAttribute {
                parents.append(enumDecl.name.text)
            }
        }

        return parents
    }
}
