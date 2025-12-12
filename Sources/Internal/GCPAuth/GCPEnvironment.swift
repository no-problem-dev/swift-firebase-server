import Foundation

/// GCP環境情報を提供するシングルトン
///
/// 環境に応じてプロジェクトIDとアクセストークンを自動取得する:
/// - Cloud Run: メタデータサーバーから取得
/// - ローカル: gcloud CLI 経由で取得
///
/// 取得した情報はキャッシュされ、トークンは有効期限が近づくと自動リフレッシュされる。
public actor GCPEnvironment {
    /// シングルトンインスタンス
    public static let shared = GCPEnvironment()

    /// 環境種別
    public enum Mode: Sendable {
        /// Cloud Run 環境（メタデータサーバーから取得）
        case cloudRun
        /// ローカル開発環境（gcloud CLI から取得）
        case local
    }

    /// 検出された環境モード
    public let mode: Mode

    /// キャッシュされたプロジェクトID
    private var cachedProjectId: String?

    /// キャッシュされたトークン情報
    private var tokenCache: TokenCache?

    /// HTTPクライアントプロバイダー
    private let httpClientProvider: HTTPClientProvider

    private init() {
        self.httpClientProvider = HTTPClientProvider()
        self.mode = Self.detectEnvironment()
    }

    /// テスト用の初期化
    internal init(httpClientProvider: HTTPClientProvider, mode: Mode) {
        self.httpClientProvider = httpClientProvider
        self.mode = mode
    }

    // MARK: - Public API

    /// GCPConfiguration から解決済み設定を取得
    ///
    /// - Parameter config: GCP設定
    /// - Returns: 解決済みの設定（projectId, token が確定した状態）
    /// - Throws: `GCPAuthError` 自動取得に失敗した場合
    public func resolve(_ config: GCPConfiguration) async throws -> ResolvedGCPConfiguration {
        switch config {
        case .auto:
            let credentials = try await getCredentials()
            return ResolvedGCPConfiguration(
                projectId: credentials.projectId,
                token: credentials.token,
                databaseId: "(default)",
                isEmulator: false
            )

        case .autoWithDatabase(let databaseId):
            let credentials = try await getCredentials()
            return ResolvedGCPConfiguration(
                projectId: credentials.projectId,
                token: credentials.token,
                databaseId: databaseId,
                isEmulator: false
            )

        case .emulator(let projectId):
            return ResolvedGCPConfiguration(
                projectId: projectId,
                token: "owner",
                databaseId: "(default)",
                isEmulator: true
            )

        case .explicit(let projectId, let token):
            return ResolvedGCPConfiguration(
                projectId: projectId,
                token: token,
                databaseId: "(default)",
                isEmulator: false
            )
        }
    }

    /// プロジェクトIDとトークンをまとめて取得
    ///
    /// - Returns: プロジェクトIDとトークンのタプル
    /// - Throws: `GCPAuthError` 取得に失敗した場合
    public func getCredentials() async throws -> (projectId: String, token: String) {
        async let projectId = getProjectId()
        async let token = getAccessToken()
        return try await (projectId, token)
    }

    /// プロジェクトIDを取得
    ///
    /// キャッシュがある場合はキャッシュから返す。
    ///
    /// - Returns: プロジェクトID
    /// - Throws: `GCPAuthError` 取得に失敗した場合
    public func getProjectId() async throws -> String {
        if let cached = cachedProjectId {
            return cached
        }

        let projectId = try await fetchProjectId()
        cachedProjectId = projectId
        return projectId
    }

    /// アクセストークンを取得
    ///
    /// キャッシュが有効な場合はキャッシュから返し、
    /// 無効な場合は新しいトークンを取得してキャッシュを更新する。
    ///
    /// - Returns: アクセストークン
    /// - Throws: `GCPAuthError` 取得に失敗した場合
    public func getAccessToken() async throws -> String {
        if let cache = tokenCache, cache.isValid {
            return cache.token
        }

        let (token, expiresIn) = try await fetchToken()
        tokenCache = TokenCache(token: token, expiresIn: expiresIn)
        return token
    }

    /// キャッシュをクリア（テスト用）
    public func clearCache() {
        cachedProjectId = nil
        tokenCache = nil
    }

    // MARK: - Private

    /// 環境に応じてプロジェクトIDを取得
    private func fetchProjectId() async throws -> String {
        switch mode {
        case .cloudRun:
            let client = MetadataServerClient(httpClientProvider: httpClientProvider)
            return try await client.fetchProjectId()
        case .local:
            let client = LocalAuthClient()
            return try await client.fetchProjectId()
        }
    }

    /// 環境に応じてトークンを取得
    private func fetchToken() async throws -> (token: String, expiresIn: Int) {
        switch mode {
        case .cloudRun:
            let client = MetadataServerClient(httpClientProvider: httpClientProvider)
            return try await client.fetchToken()
        case .local:
            let client = LocalAuthClient()
            let token = try await client.fetchToken()
            // gcloud CLI は expiresIn を返さないので、デフォルト値を設定（55分）
            return (token, 3300)
        }
    }

    /// 実行環境を検出
    private static func detectEnvironment() -> Mode {
        // K_SERVICE は Cloud Run が自動設定する環境変数
        // K_REVISION も Cloud Run 固有
        if ProcessInfo.processInfo.environment["K_SERVICE"] != nil
            || ProcessInfo.processInfo.environment["K_REVISION"] != nil
        {
            return .cloudRun
        }
        return .local
    }
}
