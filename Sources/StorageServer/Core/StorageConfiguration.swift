import Foundation
import Internal

/// Cloud Storageクライアントの設定
public struct StorageConfiguration: ServiceConfiguration, EmulatorConfigurable, Sendable {
    /// Google Cloud プロジェクトID
    public let projectId: String

    /// バケット名
    public let bucket: String

    /// ベースURL（本番 or エミュレーター）
    public let baseURL: URL

    /// アップロード用ベースURL
    public let uploadBaseURL: URL

    /// リクエストタイムアウト（秒）
    public let timeout: TimeInterval

    /// エミュレーター使用フラグ
    public let useEmulator: Bool

    /// 本番環境用の初期化
    /// - Parameters:
    ///   - projectId: Google CloudプロジェクトID
    ///   - bucket: バケット名（例: "my-project.appspot.com"）
    ///   - timeout: タイムアウト秒数（デフォルト: 60秒）
    public init(
        projectId: String,
        bucket: String,
        timeout: TimeInterval = 60
    ) {
        self.projectId = projectId
        self.bucket = bucket
        self.baseURL = URL(string: "https://storage.googleapis.com/storage/v1")!
        self.uploadBaseURL = URL(string: "https://storage.googleapis.com/upload/storage/v1")!
        self.timeout = timeout
        self.useEmulator = false
        self.emulatorHost = nil
    }

    /// エミュレーター用の初期化
    /// - Parameters:
    ///   - projectId: Google CloudプロジェクトID
    ///   - bucket: バケット名
    ///   - host: エミュレーターホスト（デフォルト: "localhost"）
    ///   - port: エミュレーターポート（デフォルト: 9199）
    ///   - timeout: タイムアウト秒数（デフォルト: 60秒）
    public static func emulator(
        projectId: String,
        bucket: String,
        host: String = EmulatorConfig.defaultHost,
        port: Int = EmulatorConfig.defaultStoragePort,
        timeout: TimeInterval = 60
    ) -> StorageConfiguration {
        let emulator = EmulatorConfig(host: host, port: port)
        return StorageConfiguration(
            projectId: projectId,
            bucket: bucket,
            baseURL: emulator.buildURL(path: "/v0"),
            uploadBaseURL: emulator.buildURL(path: "/v0"),
            timeout: timeout,
            useEmulator: true,
            emulatorHost: "\(host):\(port)"
        )
    }

    /// EmulatorConfigurable準拠
    public static func emulator(
        projectId: String,
        host: String,
        port: Int,
        timeout: TimeInterval
    ) -> StorageConfiguration {
        // バケット名はprojectIdから推測
        emulator(
            projectId: projectId,
            bucket: "\(projectId).appspot.com",
            host: host,
            port: port,
            timeout: timeout
        )
    }

    /// エミュレーターホスト（公開URL生成用）
    internal let emulatorHost: String?

    /// 内部初期化
    private init(
        projectId: String,
        bucket: String,
        baseURL: URL,
        uploadBaseURL: URL,
        timeout: TimeInterval,
        useEmulator: Bool,
        emulatorHost: String?
    ) {
        self.projectId = projectId
        self.bucket = bucket
        self.baseURL = baseURL
        self.uploadBaseURL = uploadBaseURL
        self.timeout = timeout
        self.useEmulator = useEmulator
        self.emulatorHost = emulatorHost
    }

    // MARK: - URL Builders

    /// オブジェクトの公開URL
    /// - Parameter path: オブジェクトパス（例: "images/photo.jpg"）
    /// - Returns: 公開URL
    public func publicURL(for path: String) -> URL {
        if useEmulator, let host = emulatorHost {
            return URL(string: "http://\(host)/\(bucket)/\(path)")!
        }
        return URL(string: "https://storage.googleapis.com/\(bucket)/\(path)")!
    }
}
