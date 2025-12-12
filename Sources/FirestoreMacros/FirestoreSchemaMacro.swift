import SwiftSyntax
import SwiftSyntaxMacros

/// `@FirestoreSchema`マクロの実装
///
/// enumに適用し、Firestoreスキーマの名前空間として機能します。
/// 現在は追加のコード生成は行わず、ドキュメント目的のマーカーとして機能します。
///
/// 生成例:
/// ```swift
/// @FirestoreSchema
/// enum Schema {
///     @Collection("users")
///     enum users {
///         @SubCollection("books", parent: users.self)
///         enum books
///     }
/// }
///
/// // 使用例
/// Schema.users.collectionPath                    // "users"
/// Schema.users.documentPath("userId")            // "users/userId"
/// Schema.users.books.collectionPath("userId")    // "users/userId/books"
/// ```
public struct FirestoreSchemaMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // enumであることを確認
        guard declaration.as(EnumDeclSyntax.self) != nil else {
            throw MacroError.message("@FirestoreSchema can only be applied to enums")
        }

        // 現在は追加のメンバー生成なし
        // 将来的にはスキーマバリデーションやヘルパーメソッドを追加可能
        return []
    }
}
