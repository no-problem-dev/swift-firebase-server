import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - FirestoreModelMacro

public struct FirestoreModelMacro {}

// MARK: - MemberMacro

extension FirestoreModelMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Reject anything that is not a struct
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.requiresStruct
        }

        // The model-wide default strategy
        let keyStrategy = extractKeyStrategy(from: node)

        // Stored properties with their per-field attributes resolved
        let properties = collectProperties(from: structDecl, defaultStrategy: keyStrategy)

        var declarations: [DeclSyntax] = []

        // CodingKeys is only worth generating when some key differs from its property name:
        // - a custom @Field key
        // - a snakeCase strategy
        // - a @FieldIgnore to leave out
        let needsCodingKeys = properties.contains { prop in
            prop.customKey != nil || prop.strategy == .snakeCase || prop.isIgnored
        }

        if needsCodingKeys {
            let codingKeysDecl = generateCodingKeys(properties: properties)
            declarations.append(codingKeysDecl)
        }

        let fieldsDecl = generateFieldsEnum(typeName: structDecl.name.text, properties: properties)
        declarations.append(fieldsDecl)

        return declarations
    }

    private static func generateFieldsEnum(typeName: String, properties: [PropertyInfo]) -> DeclSyntax {
        var fieldDeclarations: [String] = []

        for prop in properties {
            if prop.isIgnored {
                continue
            }

            let propertyName = prop.name
            let firestoreKey = prop.effectiveKey

            fieldDeclarations.append("static let \(propertyName) = FieldPath<\(typeName)>(\"\(firestoreKey)\")")
        }

        let fieldsBody = fieldDeclarations.joined(separator: "\n    ")

        return DeclSyntax(stringLiteral: """
            enum Fields {
                \(fieldsBody)
            }
            """
        )
    }

    // MARK: - Private Helpers

    /// Reads `keyStrategy:` off the attribute.
    ///
    /// Falls back to `.useDefault` when the argument is absent or names a case this macro does
    /// not know, so an unrecognized strategy silently means "no conversion".
    private static func extractKeyStrategy(from node: AttributeSyntax) -> KeyStrategy {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
            return .useDefault
        }

        for arg in arguments {
            if arg.label?.text == "keyStrategy",
               let memberAccess = arg.expression.as(MemberAccessExprSyntax.self) {
                switch memberAccess.declName.baseName.text {
                case "snakeCase":
                    return .snakeCase
                case "useDefault":
                    return .useDefault
                default:
                    return .useDefault
                }
            }
        }

        return .useDefault
    }

    /// Collects the struct's stored properties with their `@Field` and `@FieldIgnore` attributes
    /// resolved against the model default.
    ///
    /// Only the first binding of each `var`/`let` is read, so a multiple-binding declaration
    /// such as `let a, b: String` contributes only `a`.
    private static func collectProperties(
        from structDecl: StructDeclSyntax,
        defaultStrategy: KeyStrategy
    ) -> [PropertyInfo] {
        var properties: [PropertyInfo] = []

        for member in structDecl.memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else {
                continue
            }

            // Leave computed properties out of the mapping
            guard isStoredProperty(varDecl) else {
                continue
            }

            // The property name
            guard let binding = varDecl.bindings.first,
                  let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                continue
            }

            let propertyName = pattern.identifier.text

            // Read the attributes on the property
            var customKey: String?
            var fieldStrategy: KeyStrategy?
            var isIgnored = false

            for attribute in varDecl.attributes {
                guard let attr = attribute.as(AttributeSyntax.self),
                      let identifier = attr.attributeName.as(IdentifierTypeSyntax.self) else {
                    continue
                }

                switch identifier.name.text {
                case "Field":
                    // Either @Field("key") or @Field(strategy: .snakeCase)
                    if let key = FieldMacro.extractKey(from: attr) {
                        customKey = key
                    } else if let strategy = FieldStrategyMacro.extractStrategy(from: attr) {
                        fieldStrategy = KeyStrategy(rawValue: strategy)
                    }
                case "FieldIgnore":
                    isIgnored = true
                default:
                    break
                }
            }

            // A per-field strategy beats the model default
            let effectiveStrategy = fieldStrategy ?? defaultStrategy

            properties.append(PropertyInfo(
                name: propertyName,
                customKey: customKey,
                strategy: effectiveStrategy,
                isIgnored: isIgnored
            ))
        }

        return properties
    }

    /// Reports whether the declaration is a stored property that belongs in the mapping.
    ///
    /// Detection works off an explicit accessor list: a `get` or `set` accessor means computed,
    /// while `willSet`/`didSet` still count as stored. A getter written in shorthand
    /// (`var name: String { "" }`) parses as a code block rather than an accessor list and is
    /// therefore reported as stored.
    private static func isStoredProperty(_ varDecl: VariableDeclSyntax) -> Bool {
        guard let binding = varDecl.bindings.first else {
            return false
        }

        // An accessor block may mean the property is computed
        if let accessorBlock = binding.accessorBlock {
            // A get accessor means computed
            if case .accessors(let accessors) = accessorBlock.accessors {
                for accessor in accessors {
                    if accessor.accessorSpecifier.tokenKind == .keyword(.get) ||
                        accessor.accessorSpecifier.tokenKind == .keyword(.set) {
                        // willSet/didSet leave the property stored
                        if accessor.accessorSpecifier.tokenKind != .keyword(.willSet) &&
                            accessor.accessorSpecifier.tokenKind != .keyword(.didSet) {
                            return false
                        }
                    }
                }
            }
        }

        return true
    }

    /// Generates the `CodingKeys` enum, one case per mapped property.
    private static func generateCodingKeys(properties: [PropertyInfo]) -> DeclSyntax {
        var caseDeclarations: [String] = []

        for prop in properties {
            // @FieldIgnore properties get no case, which is what excludes them
            if prop.isIgnored {
                continue
            }

            let caseName = prop.name
            let keyValue = prop.effectiveKey

            if caseName == keyValue {
                // Same name either way, so the raw value can be left off
                caseDeclarations.append("case \(caseName)")
            } else {
                // A custom or converted key
                caseDeclarations.append("case \(caseName) = \"\(keyValue)\"")
            }
        }

        // Join the cases; the indentation comes from the DeclSyntax literal below
        let casesBody = caseDeclarations.joined(separator: "\n    ")

        return DeclSyntax(stringLiteral: """
            enum CodingKeys: String, CodingKey {
                \(casesBody)
            }
            """
        )
    }

}

// MARK: - ExtensionMacro

extension FirestoreModelMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // FirestoreModelProtocol brings Sendable with it, so only Codable has to be added here
        // Both go in one extension so the compiler still synthesizes the Codable conformance
        let ext: DeclSyntax = """
            extension \(type.trimmed): FirestoreModelProtocol, Codable {}
            """

        guard let extensionDecl = ext.as(ExtensionDeclSyntax.self) else {
            return []
        }

        return [extensionDecl]
    }
}

// MARK: - Supporting Types

/// The macro-side mirror of `FirestoreKeyStrategy`.
///
/// The raw values match the case names as written in the attribute, which is how a
/// `@Field(strategy:)` argument is turned back into a strategy.
enum KeyStrategy: String {
    case useDefault
    case snakeCase

    func transform(_ propertyName: String) -> String {
        switch self {
        case .useDefault:
            return propertyName
        case .snakeCase:
            return propertyName.convertToSnakeCase()
        }
    }
}

struct PropertyInfo {
    let name: String
    let customKey: String?
    let strategy: KeyStrategy
    let isIgnored: Bool

    /// The Firestore field name for this property.
    ///
    /// A `@Field("key")` wins outright; otherwise the resolved strategy is applied to the
    /// property name.
    var effectiveKey: String {
        if let customKey = customKey {
            return customKey
        }
        return strategy.transform(name)
    }
}

// MARK: - String Extension for Snake Case Conversion

extension String {
    /// Converts camelCase to snake_case at expansion time.
    ///
    /// Mirrors the runtime conversion in FirestoreServer's `KeyStrategy`, which a compiler
    /// plugin cannot import — the two have to stay in step or a key baked into `CodingKeys`
    /// stops matching what the encoder would produce.
    func convertToSnakeCase() -> String {
        guard !isEmpty else { return self }

        let chars = Array(self)
        var result = ""

        for (index, char) in chars.enumerated() {
            if char.isUppercase {
                let isFirst = index == 0
                let previousIsUppercase = index > 0 && chars[index - 1].isUppercase
                let nextIsLowercase = index + 1 < chars.count && chars[index + 1].isLowercase
                let previousIsUnderscore = index > 0 && chars[index - 1] == "_"

                // Insert an underscore when:
                // 1. this is not the first character, and
                // 2. the previous character is not already an underscore, and
                // 3. the previous character is lowercase, or it is uppercase and the next one
                //    is lowercase (the last capital of a run, as in URLString)
                if !isFirst && !previousIsUnderscore {
                    if !previousIsUppercase || nextIsLowercase {
                        result.append("_")
                    }
                }
                result.append(char.lowercased())
            } else {
                result.append(char)
            }
        }

        return result
    }
}
