import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - FieldMacro

/// `@Field("key")`マクロの実装
///
/// このマクロはプロパティに付与され、カスタムのFirestoreキー名を指定します。
/// 実際のコード生成は行わず、`@FirestoreModel`マクロがこの属性を読み取って
/// CodingKeysを生成します。
public struct FieldMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // このマクロは単なるマーカーとして機能
        // 実際のCodingKeys生成は@FirestoreModelが行う
        // プロパティ宣言であることを確認
        guard declaration.as(VariableDeclSyntax.self) != nil else {
            throw MacroError.invalidArgument("@Field can only be applied to properties")
        }

        // 引数の検証
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
              let firstArg = arguments.first,
              firstArg.expression.as(StringLiteralExprSyntax.self) != nil
        else {
            throw MacroError.invalidArgument("@Field requires a string literal key")
        }

        // コード生成なし（マーカーのみ）
        return []
    }

    /// 属性からカスタムキー名を抽出
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

/// `@Field(strategy: .snakeCase)`マクロの実装
///
/// このマクロはプロパティに付与され、そのフィールドのキー変換戦略を指定します。
/// 実際のコード生成は行わず、`@FirestoreModel`マクロがこの属性を読み取って
/// CodingKeysを生成します。
public struct FieldStrategyMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // プロパティ宣言であることを確認
        guard declaration.as(VariableDeclSyntax.self) != nil else {
            throw MacroError.invalidArgument("@Field(strategy:) can only be applied to properties")
        }

        // 引数の検証
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
              let firstArg = arguments.first,
              firstArg.label?.text == "strategy"
        else {
            throw MacroError.invalidArgument("@Field(strategy:) requires a strategy argument")
        }

        // コード生成なし（マーカーのみ）
        return []
    }

    /// 属性から戦略を抽出
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
