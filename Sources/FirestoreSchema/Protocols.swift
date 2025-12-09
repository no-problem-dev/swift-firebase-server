import FirestoreServer

// MARK: - Schema Protocol

/// Firestoreスキーマのルートプロトコル
public protocol FirestoreSchemaProtocol: Sendable {
    /// データベースパス
    var database: DatabasePath { get }

    /// FirestoreClientへの参照
    var client: FirestoreClient { get }

    init(client: FirestoreClient)
}

// MARK: - Collection Protocol

/// Firestoreコレクションを表すプロトコル
public protocol FirestoreCollectionProtocol: Sendable {
    /// コレクションID
    static var collectionId: String { get }

    /// データベースパス
    var database: DatabasePath { get }

    /// FirestoreClientへの参照
    var client: FirestoreClient { get }

    /// 親ドキュメントパス（ルートコレクションの場合はnil）
    var parentPath: String? { get }

    /// コレクション参照を取得
    var reference: CollectionReference { get }
}

extension FirestoreCollectionProtocol {
    public var reference: CollectionReference {
        if let parentPath = parentPath {
            let fullPath = "\(parentPath)/\(Self.collectionId)"
            // swiftlint:disable:next force_try
            return CollectionReference(database: database, path: try! CollectionPath(fullPath))
        } else {
            // swiftlint:disable:next force_try
            return CollectionReference(database: database, path: try! CollectionPath(Self.collectionId))
        }
    }
}

// MARK: - Document Protocol

/// Firestoreドキュメントを表すプロトコル
public protocol FirestoreDocumentProtocol: Sendable {
    /// ドキュメントID
    var documentId: String { get }

    /// データベースパス
    var database: DatabasePath { get }

    /// FirestoreClientへの参照
    var client: FirestoreClient { get }

    /// 親コレクションのパス
    var collectionPath: String { get }

    /// ドキュメント参照を取得
    var reference: DocumentReference { get }
}

extension FirestoreDocumentProtocol {
    public var reference: DocumentReference {
        let fullPath = "\(collectionPath)/\(documentId)"
        // swiftlint:disable:next force_try
        return DocumentReference(database: database, path: try! DocumentPath(fullPath))
    }
}

// MARK: - Document Operations

extension FirestoreDocumentProtocol {
    /// ドキュメントを取得
    public func get<T: Decodable>(
        as type: T.Type,
        authorization: String
    ) async throws -> T {
        try await client.getDocument(reference, as: type, authorization: authorization)
    }

    /// ドキュメントを作成
    public func create<T: Encodable>(
        data: T,
        authorization: String
    ) async throws {
        try await client.createDocument(reference, data: data, authorization: authorization)
    }

    /// ドキュメントを更新
    public func update<T: Encodable>(
        data: T,
        authorization: String
    ) async throws {
        try await client.updateDocument(reference, data: data, authorization: authorization)
    }

    /// ドキュメントを削除
    public func delete(authorization: String) async throws {
        try await client.deleteDocument(reference, authorization: authorization)
    }
}

// MARK: - Collection Operations

extension FirestoreCollectionProtocol {
    /// クエリを開始
    public func query<T: Decodable & Sendable>(as type: T.Type) -> Query<T> {
        reference.query(as: type)
    }

    /// クエリを実行
    public func getAll<T: Decodable & Sendable>(
        as type: T.Type,
        authorization: String,
        pageSize: Int = 100,
        pageToken: String? = nil
    ) async throws -> (documents: [T], nextPageToken: String?) {
        try await client.listDocuments(
            in: reference,
            as: type,
            authorization: authorization,
            pageSize: pageSize,
            pageToken: pageToken
        )
    }

    /// クエリを実行して結果を取得
    public func execute<T: Decodable & Sendable>(
        _ query: Query<T>,
        authorization: String
    ) async throws -> [T] {
        try await client.runQuery(query, authorization: authorization)
    }
}
