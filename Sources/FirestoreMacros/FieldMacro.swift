import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - FieldMacro

/// The expansion behind `@Field("key")`.
///
/// It generates nothing. Its whole job is to validate the attribute and leave it on the
/// property for `@FirestoreModel` to read when building `CodingKeys` and `Fields`.
public struct FieldMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // The attribute is only a marker; @FirestoreModel does the CodingKeys work
        // Reject anything that is not a property
        guard declaration.as(VariableDeclSyntax.self) != nil else {
            throw MacroError.invalidArgument("@Field can only be applied to properties")
        }

        // The key has to be a string literal so it can be read at expansion time
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
              let firstArg = arguments.first,
              firstArg.expression.as(StringLiteralExprSyntax.self) != nil
        else {
            throw MacroError.invalidArgument("@Field requires a string literal key")
        }

        // Nothing to emit
        return []
    }

    /// Reads the custom key out of the attribute.
    ///
    /// Returns `nil` when the first argument is not a plain string literal — an interpolated
    /// one has no single segment to read — and also for `@Field(strategy:)`, which is how
    /// `@FirestoreModel` tells the two spellings apart.
    static func extractKey(from attribute: AttributeSyntax) -> String? {
        guard let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
              let firstArg = arguments.first,
              let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
              let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
        else {
            return nil
        }
        return segment.content.text
    }
}

// MARK: - FieldStrategyMacro

/// The expansion behind `@Field(strategy: .snakeCase)`.
///
/// Like `FieldMacro` it generates nothing and exists to validate the attribute that
/// `@FirestoreModel` reads when resolving the key for that one property.
public struct FieldStrategyMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Reject anything that is not a property
        guard declaration.as(VariableDeclSyntax.self) != nil else {
            throw MacroError.invalidArgument("@Field(strategy:) can only be applied to properties")
        }

        // The first argument has to carry the strategy label
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
              let firstArg = arguments.first,
              firstArg.label?.text == "strategy"
        else {
            throw MacroError.invalidArgument("@Field(strategy:) requires a strategy argument")
        }

        // Nothing to emit
        return []
    }

    /// Reads the strategy's case name out of the attribute.
    ///
    /// Returns the bare name, such as `snakeCase`, which the caller matches against
    /// `KeyStrategy`'s raw values; `nil` means the attribute was the `@Field("key")` spelling.
    static func extractStrategy(from attribute: AttributeSyntax) -> String? {
        guard let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
              let firstArg = arguments.first,
              firstArg.label?.text == "strategy",
              let memberAccess = firstArg.expression.as(MemberAccessExprSyntax.self)
        else {
            return nil
        }
        return memberAccess.declName.baseName.text
    }
}
