import AsyncHTTPClient
import Foundation

/// Firestore REST APIクライアント
///
/// サーバーサイドSwiftからFirestoreにアクセスするための軽量クライアント。
/// Firebase SDKを使用せず、REST APIを直接呼び出す。
///
/// 使用例:
/// ```swift
/// let firestore = FirestoreClient(projectId: "my-project")
///
/// // コレクション・ドキュメント参照
/// let usersRef = firestore.collection("users")
/// let userRef = usersRef.document("abc123")
/// let booksRef = userRef.collection("books")
///
/// // データ操作（ID Tokenを渡す）
/// let user: User = try await firestore.getDocument(userRef, authorization: idToken)
/// ```
public final class FirestoreClient: Sendable {
    /// 設定
    public let configuration: FirestoreConfiguration

    /// HTTPクライアント
    private let httpClient: HTTPClient

    /// 本番環境用の初期化
    /// - Parameters:
    ///   - projectId: Google CloudプロジェクトID
    ///   - databaseId: データベースID（デフォルト: "(default)"）
    public convenience init(projectId: String, databaseId: String = "(default)") {
        let config = FirestoreConfiguration(projectId: projectId, databaseId: databaseId)
        self.init(configuration: config)
    }

    /// 設定を指定して初期化
    /// - Parameter configuration: Firestore設定
    public init(configuration: FirestoreConfiguration) {
        self.configuration = configuration
        self.httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
    }

    deinit {
        try? httpClient.syncShutdown()
    }

    // MARK: - Reference生成

    /// ルートコレクションへの参照を取得
    /// - Parameter collectionId: コレクションID
    /// - Returns: コレクション参照
    public func collection(_ collectionId: String) -> CollectionReference {
        let path = try! CollectionPath(collectionId)
        return CollectionReference(database: configuration.database, path: path)
    }

    /// ドキュメントへの参照を取得（パス直接指定）
    /// - Parameter path: ドキュメントパス（例: "users/abc123"）
    /// - Returns: ドキュメント参照
    /// - Throws: パスが無効な場合
    public func document(_ path: String) throws -> DocumentReference {
        let docPath = try DocumentPath(path)
        return DocumentReference(database: configuration.database, path: docPath)
    }

    // MARK: - Internal

    /// HTTPクライアントへのアクセス（内部用）
    internal var client: HTTPClient {
        httpClient
    }
}
