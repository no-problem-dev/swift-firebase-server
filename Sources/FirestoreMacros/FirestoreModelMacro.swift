import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - FirestoreModelMacro

/// `@FirestoreModel`マクロの実装
///
/// このマクロは構造体に付与され、以下を生成します:
/// - `CodingKeys` enum（@Field, @FieldIgnore, keyStrategyに基づく）
/// - `Codable`, `Sendable` プロトコル準拠
public struct FirestoreModelMacro {}

// MARK: - MemberMacro

extension FirestoreModelMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // 構造体であることを確認
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.requiresStruct
        }

        // keyStrategyを取得
        let keyStrategy = extractKeyStrategy(from: node)

        // プロパティ情報を収集
        let properties = collectProperties(from: structDecl, defaultStrategy: keyStrategy)

        // CodingKeysを生成する必要があるか確認
        // - カスタムキーがある
        // - keyStrategyがsnakeCaseである
        // - @FieldIgnoreがある
        let needsCodingKeys = properties.contains { prop in
            prop.customKey != nil || prop.strategy == .snakeCase || prop.isIgnored
        }

        guard needsCodingKeys else {
            // CodingKeys不要（全てデフォルト）
            return []
        }

        // CodingKeysを生成
        let codingKeysDecl = generateCodingKeys(properties: properties)

        return [codingKeysDecl]
    }

    // MARK: - Private Helpers

    /// マクロ属性からkeyStrategyを抽出
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

    /// 構造体のプロパティ情報を収集
    private static func collectProperties(
        from structDecl: StructDeclSyntax,
        defaultStrategy: KeyStrategy
    ) -> [PropertyInfo] {
        var properties: [PropertyInfo] = []

        for member in structDecl.memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else {
                continue
            }

            // 計算プロパティは除外
            guard isStoredProperty(varDecl) else {
                continue
            }

            // プロパティ名を取得
            guard let binding = varDecl.bindings.first,
                  let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                continue
            }

            let propertyName = pattern.identifier.text

            // 属性を解析
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
                    // @Field("key") または @Field(strategy: .snakeCase)
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

            // 最終的な戦略を決定
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

    /// 保存プロパティかどうかを判定（計算プロパティを除外）
    private static func isStoredProperty(_ varDecl: VariableDeclSyntax) -> Bool {
        guard let binding = varDecl.bindings.first else {
            return false
        }

        // アクセサブロックがある場合は計算プロパティの可能性
        if let accessorBlock = binding.accessorBlock {
            // getキーワードがあれば計算プロパティ
            if case .accessors(let accessors) = accessorBlock.accessors {
                for accessor in accessors {
                    if accessor.accessorSpecifier.tokenKind == .keyword(.get) ||
                        accessor.accessorSpecifier.tokenKind == .keyword(.set) {
                        // willSet/didSetは保存プロパティ
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

    /// CodingKeys enumを生成
    private static func generateCodingKeys(properties: [PropertyInfo]) -> DeclSyntax {
        var caseDeclarations: [String] = []

        for prop in properties {
            // @FieldIgnoreはスキップ
            if prop.isIgnored {
                continue
            }

            let caseName = prop.name
            let keyValue = prop.effectiveKey

            if caseName == keyValue {
                // キー名がプロパティ名と同じ場合はrawValueを省略
                caseDeclarations.append("case \(caseName)")
            } else {
                // カスタムキーまたは変換されたキー
                caseDeclarations.append("case \(caseName) = \"\(keyValue)\"")
            }
        }

        // 各caseを改行でjoin（インデントはDeclSyntaxリテラル内で統一）
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
        // Codable, Sendable, FirestoreModelProtocol を付与
        // Codable の synthesized conformance を有効にするため、同じ extension で宣言する
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

/// キー変換戦略
enum KeyStrategy: String {
    case useDefault
    case snakeCase

    /// プロパティ名をキー名に変換
    func transform(_ propertyName: String) -> String {
        switch self {
        case .useDefault:
            return propertyName
        case .snakeCase:
            return propertyName.convertToSnakeCase()
        }
    }
}

/// プロパティ情報
struct PropertyInfo {
    let name: String
    let customKey: String?
    let strategy: KeyStrategy
    let isIgnored: Bool

    /// 最終的なキー名を取得
    var effectiveKey: String {
        if let customKey = customKey {
            return customKey
        }
        return strategy.transform(name)
    }
}

// MARK: - String Extension for Snake Case Conversion

extension String {
    /// camelCase を snake_case に変換
    ///
    /// Phase 1のKeyStrategy.swiftと同じロジック
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

                // アンダースコアを追加するケース:
                // 1. 先頭でない かつ
                // 2. 前の文字がアンダースコアでない かつ
                // 3. (前の文字が小文字である または (前の文字が大文字で次の文字が小文字である))
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
