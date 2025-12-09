/// コレクションへの参照
///
/// コレクション参照は軽量なオブジェクトで、特定のコレクションの位置を指す。
/// 実際のデータ操作は`FirestoreClient`を通じて行う。
///
/// 使用例:
/// ```swift
/// let usersRef = firestore.collection("users")
/// let booksRef = usersRef.document("abc").collection("books")
/// ```
public struct CollectionReference: Sendable, Hashable {
    /// データベースパス
    public let database: DatabasePath

    /// コレクションへの論理パス
    public let path: CollectionPath

    /// 初期化
    public init(database: DatabasePath, path: CollectionPath) {
        self.database = database
        self.path = path
    }

    /// コレクションID
    public var collectionId: String {
        path.collectionId
    }

    /// 親ドキュメントへの参照（ルートコレクションの場合はnil）
    public var parent: DocumentReference? {
        guard let parentPath = path.parent else { return nil }
        return DocumentReference(database: database, path: parentPath)
    }

    /// このコレクション内のドキュメントへの参照を生成
    /// - Parameter documentId: ドキュメントID
    /// - Returns: ドキュメント参照
    public func document(_ documentId: String) -> DocumentReference {
        DocumentReference(database: database, path: path.document(documentId))
    }

    // MARK: - REST API用パス生成

    /// REST API: parent パラメータ
    /// 例: `projects/my-project/databases/(default)/documents` または
    ///     `projects/my-project/databases/(default)/documents/users/abc`
    public var restParent: String {
        if let parentPath = path.parent {
            return "\(database.documentsPath)/\(parentPath.rawValue)"
        } else {
            return database.documentsPath
        }
    }

    /// REST API: collectionId パラメータ
    public var restCollectionId: String {
        collectionId
    }

    /// REST API: 完全なコレクションパス
    /// 例: `projects/my-project/databases/(default)/documents/users`
    public var restPath: String {
        "\(database.documentsPath)/\(path.rawValue)"
    }
}

extension CollectionReference: CustomStringConvertible {
    public var description: String {
        path.rawValue
    }
}

// MARK: - Query Builder

extension CollectionReference {
    /// このコレクションに対するクエリを開始
    /// - Parameter type: 結果のデコード型
    /// - Returns: クエリビルダー
    public func query<T: Decodable & Sendable>(as type: T.Type) -> Query<T> {
        Query(collection: self)
    }
}
