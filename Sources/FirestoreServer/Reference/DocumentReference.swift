/// ドキュメントへの参照
///
/// ドキュメント参照は軽量なオブジェクトで、特定のドキュメントの位置を指す。
/// 実際のデータ操作は`FirestoreClient`を通じて行う。
///
/// 使用例:
/// ```swift
/// let userRef = firestore.collection("users").document("abc")
/// let bookRef = userRef.collection("books").document("xyz")
/// ```
public struct DocumentReference: Sendable, Hashable {
    /// データベースパス
    public let database: DatabasePath

    /// ドキュメントへの論理パス
    public let path: DocumentPath

    /// 初期化
    public init(database: DatabasePath, path: DocumentPath) {
        self.database = database
        self.path = path
    }

    /// ドキュメントID
    public var documentId: String {
        path.documentId
    }

    /// 親コレクションへの参照
    public var parent: CollectionReference {
        CollectionReference(database: database, path: path.parent)
    }

    /// このドキュメント配下のサブコレクションへの参照を生成
    /// - Parameter collectionId: コレクションID
    /// - Returns: コレクション参照
    public func collection(_ collectionId: String) -> CollectionReference {
        CollectionReference(database: database, path: path.collection(collectionId))
    }

    // MARK: - REST API用パス生成

    /// REST API: name パラメータ（完全なドキュメントパス）
    /// 例: `projects/my-project/databases/(default)/documents/users/abc`
    public var restName: String {
        "\(database.documentsPath)/\(path.rawValue)"
    }

    /// REST API: ドキュメントパス部分のみ
    /// 例: `users/abc`
    public var restDocumentPath: String {
        path.rawValue
    }
}

extension DocumentReference: CustomStringConvertible {
    public var description: String {
        path.rawValue
    }
}
