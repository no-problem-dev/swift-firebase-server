import Foundation
import Internal

/// Firestoreクライアントの設定
public struct FirestoreConfiguration: ServiceConfiguration, EmulatorConfigurable, Sendable {
    /// データベースパス
    public let database: DatabasePath

    /// Google Cloud プロジェクトID
    public var projectId: String {
        database.projectId
    }

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
        host: String = EmulatorConfig.defaultHost,
        port: Int = EmulatorConfig.defaultFirestorePort,
        timeout: TimeInterval = 30
    ) -> FirestoreConfiguration {
        let emulator = EmulatorConfig(host: host, port: port)
        return FirestoreConfiguration(
            database: DatabasePath(projectId: projectId, databaseId: databaseId),
            baseURL: emulator.buildURL(path: "/v1"),
            timeout: timeout
        )
    }

    /// EmulatorConfigurable準拠
    public static func emulator(
        projectId: String,
        host: String,
        port: Int,
        timeout: TimeInterval
    ) -> FirestoreConfiguration {
        emulator(
            projectId: projectId,
            databaseId: "(default)",
            host: host,
            port: port,
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
