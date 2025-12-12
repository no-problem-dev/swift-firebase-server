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

// MARK: - Generic Collection

/// 汎用的な型付きコレクション構造体
///
/// マクロで生成される静的パス情報と、ランタイムのクライアント情報を組み合わせて
/// 型安全なコレクション操作を提供する。
public struct FirestoreCollection<Model: Codable & Sendable>: FirestoreCollectionProtocol, Sendable {
    public typealias Document = FirestoreDocument<Model>

    public static var collectionId: String { _collectionId }
    private static var _collectionId: String { fatalError("Use instance") }

    public let collectionId: String
    public let database: DatabasePath
    public let client: FirestoreClient
    public let parentPath: String?

    public init(
        collectionId: String,
        database: DatabasePath,
        client: FirestoreClient,
        parentPath: String? = nil
    ) {
        self.collectionId = collectionId
        self.database = database
        self.client = client
        self.parentPath = parentPath
    }

    public var reference: CollectionReference {
        if let parentPath = parentPath {
            let fullPath = "\(parentPath)/\(collectionId)"
            // swiftlint:disable:next force_try
            return CollectionReference(database: database, path: try! CollectionPath(fullPath))
        } else {
            // swiftlint:disable:next force_try
            return CollectionReference(database: database, path: try! CollectionPath(collectionId))
        }
    }

    public func document(_ documentId: String) -> Document {
        Document(
            documentId: documentId,
            database: database,
            client: client,
            collectionPath: parentPath.map { "\($0)/\(collectionId)" } ?? collectionId
        )
    }
}

// MARK: - Generic Document

/// 汎用的な型付きドキュメント構造体
public struct FirestoreDocument<Model: Codable & Sendable>: FirestoreDocumentProtocol, Sendable {
    public let documentId: String
    public let database: DatabasePath
    public let client: FirestoreClient
    public let collectionPath: String

    public init(
        documentId: String,
        database: DatabasePath,
        client: FirestoreClient,
        collectionPath: String
    ) {
        self.documentId = documentId
        self.database = database
        self.client = client
        self.collectionPath = collectionPath
    }
}

// MARK: - Collection Protocol

/// Firestoreコレクションを表すプロトコル
///
/// `Model` 関連型により、型引数なしにコレクション操作ができる。
/// `document(_:)` メソッドで型付きドキュメントを取得できる。
///
/// ```swift
/// let schema = MySchema(client: firestoreClient)
/// let users = try await schema.users.getAll()  // [User]型が推論される
/// let user = try await schema.users.document("user123").get()  // User型が推論される
/// ```
public protocol FirestoreCollectionProtocol: Sendable {
    /// コレクションのモデル型
    associatedtype Model: Codable & Sendable

    /// 型付きドキュメント型
    associatedtype Document: FirestoreDocumentProtocol where Document.Model == Model

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

    /// 型付きドキュメントを取得
    func document(_ documentId: String) -> Document
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

    /// クエリを開始
    public func query() -> Query<Model> {
        reference.query(as: Model.self)
    }

    /// 全ドキュメントを取得
    public func getAll(
        pageSize: Int = 100,
        pageToken: String? = nil
    ) async throws -> (documents: [Model], nextPageToken: String?) {
        try await client.listDocuments(
            in: reference,
            as: Model.self,
            pageSize: pageSize,
            pageToken: pageToken
        )
    }

    /// クエリを実行して結果を取得
    public func execute(_ query: Query<Model>) async throws -> [Model] {
        try await client.runQuery(query)
    }
}

// MARK: - Document Protocol

/// Firestoreドキュメントを表すプロトコル
///
/// `Model` 関連型により、`get()` メソッドで型引数なしにドキュメントを取得できる。
///
/// ```swift
/// let schema = MySchema(client: firestoreClient)
/// let user = try await schema.users.document("user123").get()  // User型が推論される
/// ```
public protocol FirestoreDocumentProtocol: Sendable {
    /// ドキュメントのモデル型
    associatedtype Model: Codable & Sendable

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

    /// ドキュメントを取得
    public func get() async throws -> Model {
        try await client.getDocument(reference, as: Model.self)
    }

    /// ドキュメントを作成
    public func create(data: Model) async throws {
        try await client.createDocument(reference, data: data)
    }

    /// ドキュメントを更新
    public func update(data: Model) async throws {
        try await client.updateDocument(reference, data: data)
    }

    /// ドキュメントを削除
    public func delete() async throws {
        try await client.deleteDocument(reference)
    }
}
