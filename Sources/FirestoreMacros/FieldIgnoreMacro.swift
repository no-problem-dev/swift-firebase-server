import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - FieldIgnoreMacro

/// The expansion behind `@FieldIgnore`.
///
/// It generates nothing and takes no argument. `@FirestoreModel` reads the attribute and leaves
/// the property out of both `CodingKeys` and `Fields`.
public struct FieldIgnoreMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Reject anything that is not a property
        guard declaration.as(VariableDeclSyntax.self) != nil else {
            throw MacroError.invalidArgument("@FieldIgnore can only be applied to properties")
        }

        // Nothing to emit
        return []
    }

    /// Reports whether an attribute is `@FieldIgnore`, matching on the written name only.
    static func isFieldIgnore(_ attribute: AttributeSyntax) -> Bool {
        guard let identifier = attribute.attributeName.as(IdentifierTypeSyntax.self) else {
            return false
        }
        return identifier.name.text == "FieldIgnore"
    }
}
