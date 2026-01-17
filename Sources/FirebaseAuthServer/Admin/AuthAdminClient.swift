import Foundation
import Internal

/// Firebase Auth Admin API クライアント
///
/// Firebase Auth のユーザー管理操作（削除など）を行うためのクライアント。
/// サービスアカウント権限で動作し、GCP環境から自動的にアクセストークンを取得する。
///
/// ## 使用例
///
/// ```swift
/// // 本番環境（Cloud Run / ローカル gcloud）
/// let adminClient = try await AuthAdminClient(projectId: "my-project")
///
/// // ユーザーを削除
/// try await adminClient.deleteUser(uid: "user-123")
///
/// // エミュレーター環境
/// let emulatorClient = AuthAdminClient.emulator(projectId: "demo-project")
/// try await emulatorClient.deleteUser(uid: "user-123")
/// ```
public final class AuthAdminClient: Sendable {
    /// プロジェクトID
    public let projectId: String

    /// HTTPクライアントプロバイダー
    private let httpClientProvider: HTTPClientProvider

    /// エミュレーター設定（nilの場合は本番環境）
    private let emulatorConfig: EmulatorSettings?

    /// エミュレーター設定
    private struct EmulatorSettings: Sendable {
        let host: String
        let port: Int
    }

    // MARK: - Initializers

    /// 本番環境用の初期化
    ///
    /// GCP環境からサービスアカウントのアクセストークンを自動取得する。
    ///
    /// - Parameter projectId: Google Cloud プロジェクトID
    public init(projectId: String) {
        self.projectId = projectId
        self.httpClientProvider = HTTPClientProvider()
        self.emulatorConfig = nil
    }

    /// 本番環境用の初期化（HTTPClientProvider共有）
    ///
    /// - Parameters:
    ///   - projectId: Google Cloud プロジェクトID
    ///   - httpClientProvider: 共有HTTPClientProvider
    public init(projectId: String, httpClientProvider: HTTPClientProvider) {
        self.projectId = projectId
        self.httpClientProvider = httpClientProvider
        self.emulatorConfig = nil
    }

    /// エミュレーター用の初期化
    ///
    /// - Parameters:
    ///   - projectId: プロジェクトID
    ///   - host: エミュレーターホスト（デフォルト: "localhost"）
    ///   - port: エミュレーターポート（デフォルト: 9099）
    public static func emulator(
        projectId: String,
        host: String = EmulatorConfig.defaultHost,
        port: Int = AuthConfiguration.defaultEmulatorPort
    ) -> AuthAdminClient {
        AuthAdminClient(
            projectId: projectId,
            emulatorConfig: EmulatorSettings(host: host, port: port)
        )
    }

    /// 内部初期化（エミュレーター用）
    private init(projectId: String, emulatorConfig: EmulatorSettings) {
        self.projectId = projectId
        self.httpClientProvider = HTTPClientProvider()
        self.emulatorConfig = emulatorConfig
    }

    // MARK: - Public Methods

    /// ユーザーを削除する
    ///
    /// Firebase Auth からユーザーアカウントを完全に削除する。
    /// この操作は元に戻せない。
    ///
    /// - Parameter uid: 削除するユーザーのUID（Firebase Auth UID）
    /// - Throws: `AuthError.deleteUserFailed` 削除に失敗した場合
    /// - Throws: `AuthError.adminAPIFailed` APIリクエストに失敗した場合
    ///
    /// ## 注意事項
    ///
    /// - ユーザーが存在しない場合もエラーにはならない（冪等性）
    /// - Firestore や Storage のデータは別途削除が必要
    public func deleteUser(uid: String) async throws {
        let url = try buildDeleteUserURL(uid: uid)
        let token = try await getAccessToken()

        try await executeDelete(url: url, token: token)
    }

    // MARK: - Private Methods

    /// 削除用URLを構築
    private func buildDeleteUserURL(uid: String) throws -> URL {
        let baseURL: String
        if let emulator = emulatorConfig {
            // エミュレーター: http://{host}:{port}/identitytoolkit.googleapis.com/v1/projects/{projectId}/accounts/{uid}
            baseURL = "http://\(emulator.host):\(emulator.port)/identitytoolkit.googleapis.com/v1"
        } else {
            // 本番: https://identitytoolkit.googleapis.com/v1
            baseURL = "https://identitytoolkit.googleapis.com/v1"
        }

        let urlString = "\(baseURL)/projects/\(projectId)/accounts/\(uid)"
        guard let url = URL(string: urlString) else {
            throw AuthError.deleteUserFailed(reason: "Invalid URL: \(urlString)")
        }
        return url
    }

    /// アクセストークンを取得
    private func getAccessToken() async throws -> String {
        if emulatorConfig != nil {
            // エミュレーターでは "owner" トークンを使用
            return "owner"
        }
        // 本番環境ではGCP環境から取得
        return try await GCPEnvironment.shared.getAccessToken()
    }

    /// DELETE リクエストを実行
    private func executeDelete(url: URL, token: String) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.deleteUserFailed(reason: "Invalid response type")
        }

        // 成功: 200, 204, または 404（既に削除済み）
        switch httpResponse.statusCode {
        case 200, 204:
            return // 成功

        case 404:
            // ユーザーが存在しない場合も成功とみなす（冪等性）
            return

        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AuthError.adminAPIFailed(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }
    }
}
