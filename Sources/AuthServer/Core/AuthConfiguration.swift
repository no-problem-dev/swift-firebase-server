import Foundation
import Internal

/// Firebase Auth クライアントの設定
public struct AuthConfiguration: Sendable {
    /// Google Cloud プロジェクトID
    public let projectId: String

    /// リクエストタイムアウト（秒）
    public let timeout: TimeInterval

    /// エミュレーターモードかどうか
    public let useEmulator: Bool

    /// エミュレーターホスト（useEmulator が true の場合のみ使用）
    public let emulatorHost: String?

    /// エミュレーターポート
    public let emulatorPort: Int?

    /// Firebase Auth エミュレーターのデフォルトポート
    public static let defaultEmulatorPort = 9099

    /// Google 公開鍵エンドポイント
    public static let publicKeysURL = URL(
        string: "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com"
    )!

    // MARK: - Initializers

    /// 本番環境用の初期化
    /// - Parameters:
    ///   - projectId: Google Cloud プロジェクトID
    ///   - timeout: タイムアウト秒数（デフォルト: 30秒）
    public init(
        projectId: String,
        timeout: TimeInterval = 30
    ) {
        self.projectId = projectId
        self.timeout = timeout
        self.useEmulator = false
        self.emulatorHost = nil
        self.emulatorPort = nil
    }

    /// エミュレーター用の設定を作成
    /// - Parameters:
    ///   - projectId: Google Cloud プロジェクトID
    ///   - host: エミュレーターホスト（デフォルト: "localhost"）
    ///   - port: エミュレーターポート（デフォルト: 9099）
    ///   - timeout: タイムアウト秒数（デフォルト: 30秒）
    public static func emulator(
        projectId: String,
        host: String = EmulatorConfig.defaultHost,
        port: Int = defaultEmulatorPort,
        timeout: TimeInterval = 30
    ) -> AuthConfiguration {
        AuthConfiguration(
            projectId: projectId,
            timeout: timeout,
            useEmulator: true,
            emulatorHost: host,
            emulatorPort: port
        )
    }

    /// 内部初期化
    private init(
        projectId: String,
        timeout: TimeInterval,
        useEmulator: Bool,
        emulatorHost: String?,
        emulatorPort: Int?
    ) {
        self.projectId = projectId
        self.timeout = timeout
        self.useEmulator = useEmulator
        self.emulatorHost = emulatorHost
        self.emulatorPort = emulatorPort
    }

    // MARK: - Computed Properties

    /// 期待される issuer URL
    /// `https://securetoken.google.com/{projectId}`
    public var expectedIssuer: String {
        "https://securetoken.google.com/\(projectId)"
    }

    /// 期待される audience（= projectId）
    public var expectedAudience: String {
        projectId
    }
}
