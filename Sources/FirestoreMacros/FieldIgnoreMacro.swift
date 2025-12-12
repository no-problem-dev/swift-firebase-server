import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - FieldIgnoreMacro

/// `@FieldIgnore`マクロの実装
///
/// このマクロはプロパティに付与され、そのフィールドをCodingKeysから除外します。
/// 実際のコード生成は行わず、`@FirestoreModel`マクロがこの属性を読み取って
/// CodingKeysを生成します。
public struct FieldIgnoreMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // プロパティ宣言であることを確認
        guard declaration.as(VariableDeclSyntax.self) != nil else {
            throw MacroError.invalidArgument("@FieldIgnore can only be applied to properties")
        }

        // コード生成なし（マーカーのみ）
        return []
    }

    /// 属性が@FieldIgnoreかどうかを判定
    static func isFieldIgnore(_ attribute: AttributeSyntax) -> Bool {
        guard let identifier = attribute.attributeName.as(IdentifierTypeSyntax.self) else {
            return false
        }
        return identifier.name.text == "FieldIgnore"
    }
}
