import SwiftSyntax
import SwiftSyntaxMacros

/// `@Collection`マクロの実装
///
/// このマクロは以下を生成:
/// - `database: DatabasePath`プロパティ
/// - `client: FirestoreClient`プロパティ
/// - `parentPath: String?`プロパティ
/// - `static var collectionId: String`
/// - `init(client:parentPath:)`イニシャライザ
/// - `callAsFunction(_:) -> DocumentAccessor`
public struct CollectionMacro {}

// MARK: - MemberMacro

extension CollectionMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.requiresStruct
        }

        // コレクションIDを取得
        guard let collectionId = extractCollectionId(from: node) else {
            throw MacroError.missingCollectionId
        }

        let structName = structDecl.name.text

        var members: [DeclSyntax] = []

        // static collectionId
        members.append("""
            public static let collectionId: String = \(literal: collectionId)
            """)

        // database プロパティ
        members.append("""
            public let database: DatabasePath
            """)

        // client プロパティ
        members.append("""
            public let client: FirestoreClient
            """)

        // parentPath プロパティ
        members.append("""
            public let parentPath: String?
            """)

        // イニシャライザ
        members.append("""
            public init(client: FirestoreClient, parentPath: String?) {
                self.client = client
                self.database = client.database
                self.parentPath = parentPath
            }
            """)

        // DocumentAccessor構造体を生成
        let documentAccessorName = "\(structName)Document"
        members.append("""
            public struct \(raw: documentAccessorName): FirestoreDocumentProtocol, Sendable {
                public let documentId: String
                public let database: DatabasePath
                public let client: FirestoreClient
                public let collectionPath: String

                public init(documentId: String, database: DatabasePath, client: FirestoreClient, collectionPath: String) {
                    self.documentId = documentId
                    self.database = database
                    self.client = client
                    self.collectionPath = collectionPath
                }
            }
            """)

        // callAsFunction - ドキュメントIDでアクセス
        members.append("""
            public func callAsFunction(_ documentId: String) -> \(raw: documentAccessorName) {
                let path: String
                if let parentPath = parentPath {
                    path = "\\(parentPath)/\\(Self.collectionId)"
                } else {
                    path = Self.collectionId
                }
                return \(raw: documentAccessorName)(
                    documentId: documentId,
                    database: database,
                    client: client,
                    collectionPath: path
                )
            }
            """)

        // サブコレクションアクセサを生成
        for member in structDecl.memberBlock.members {
            guard let nestedStruct = member.decl.as(StructDeclSyntax.self) else { continue }

            // @SubCollection属性を検索
            for attribute in nestedStruct.attributes {
                guard let attr = attribute.as(AttributeSyntax.self),
                      let identifier = attr.attributeName.as(IdentifierTypeSyntax.self),
                      identifier.name.text == "SubCollection"
                else { continue }

                let subStructName = nestedStruct.name.text
                let accessorName = subStructName.lowercasedFirst()

                // DocumentAccessorにサブコレクションアクセサを追加
                // これはDocumentAccessor構造体内にextensionとして追加される
            }
        }

        return members
    }

    private static func extractCollectionId(from node: AttributeSyntax) -> String? {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
              let firstArg = arguments.first,
              let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
              let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
        else {
            return nil
        }
        return segment.content.text
    }
}

// MARK: - ExtensionMacro

extension CollectionMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let ext: DeclSyntax = """
            extension \(type.trimmed): FirestoreCollectionProtocol, Sendable {}
            """

        guard let extensionDecl = ext.as(ExtensionDeclSyntax.self) else {
            return []
        }

        return [extensionDecl]
    }
}
