import SwiftSyntax
import SwiftSyntaxMacros

/// `@Collection`マクロの実装
///
/// enumに適用し、コレクションパスアクセサとモデル型エイリアスを自動生成します。
/// ネストされている場合は自動的にサブコレクションとして扱われます。
///
/// 生成例:
/// ```swift
/// @FirestoreSchema
/// enum Schema {
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
        // enumであることを確認
        guard declaration.as(EnumDeclSyntax.self) != nil else {
            throw MacroError.message("@Collection can only be applied to enums")
        }

        // 引数を取得
        guard let args = extractArguments(from: node) else {
            throw MacroError.message("@Collection requires collectionId and model arguments: @Collection(\"name\", model: Type.self)")
        }

        // 親コレクションの階層を取得（最も近い親から順）
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
            // トップレベルコレクション
            members.append(contentsOf: generateTopLevelMembers())
        } else {
            // サブコレクション（深さに応じた引数を生成）
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

        // 引数名を生成: p1, p2, ... (親のドキュメントID)
        let paramNames = (1...depth).map { "p\($0)" }
        let paramDecls = paramNames.map { "_ \($0): String" }.joined(separator: ", ")

        // 親のdocumentPath呼び出しを構築
        // 例: depth=2の場合、Books.documentPath(p1, p2) を呼ぶ
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
                // 最初の引数（ラベルなし）= collectionId
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

    /// 親コレクションの階層を取得（最も近い親から順に）
    /// 戻り値: ["Books", "Users"] のように、直近の親から順に並んだ配列
    private static func findParentCollections(in context: some MacroExpansionContext) -> [String] {
        var parents: [String] = []

        for lexicalContext in context.lexicalContext {
            guard let enumDecl = lexicalContext.as(EnumDeclSyntax.self) else {
                continue
            }

            // このenumに@Collectionアトリビュートが付いているか確認
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
