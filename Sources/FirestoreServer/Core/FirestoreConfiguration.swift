import Foundation

/// Firestoreクライアントの設定
public struct FirestoreConfiguration: Sendable {
    /// データベースパス
    public let database: DatabasePath

    /// ベースURL（本番 or エミュレーター）
    public let baseURL: URL

    /// リクエストタイムアウト（秒）
    public let timeout: TimeInterval

    /// 本番環境用の初期化
    /// - Parameters:
    ///   - projectId: Google CloudプロジェクトID
    ///   - databaseId: データベースID（デフォルト: "(default)"）
    ///   - timeout: タイムアウト秒数（デフォルト: 30秒）
    public init(
        projectId: String,
        databaseId: String = "(default)",
        timeout: TimeInterval = 30
    ) {
        self.database = DatabasePath(projectId: projectId, databaseId: databaseId)
        self.baseURL = URL(string: "https://firestore.googleapis.com/v1")!
        self.timeout = timeout
    }

    /// エミュレーター用の初期化
    /// - Parameters:
    ///   - projectId: Google CloudプロジェクトID
    ///   - databaseId: データベースID（デフォルト: "(default)"）
    ///   - host: エミュレーターホスト（デフォルト: "localhost"）
    ///   - port: エミュレーターポート（デフォルト: 8080）
    ///   - timeout: タイムアウト秒数（デフォルト: 30秒）
    public static func emulator(
        projectId: String,
        databaseId: String = "(default)",
        host: String = "localhost",
        port: Int = 8080,
        timeout: TimeInterval = 30
    ) -> FirestoreConfiguration {
        FirestoreConfiguration(
            database: DatabasePath(projectId: projectId, databaseId: databaseId),
            baseURL: URL(string: "http://\(host):\(port)/v1")!,
            timeout: timeout
        )
    }

    /// 内部初期化（カスタムURL用）
    internal init(
        database: DatabasePath,
        baseURL: URL,
        timeout: TimeInterval
    ) {
        self.database = database
        self.baseURL = baseURL
        self.timeout = timeout
    }
}
