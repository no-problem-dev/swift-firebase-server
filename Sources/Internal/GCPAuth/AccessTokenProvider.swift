import Foundation

/// GCPアクセストークンを提供するシングルトン
///
/// 環境に応じて自動的に認証方法を切り替える:
/// - Cloud Run: メタデータサーバーからトークン取得
/// - ローカル: gcloud CLI 経由でトークン取得
/// - エミュレーター: 認証をスキップ（ダミートークンを返す）
///
/// トークンはキャッシュされ、有効期限が近づくと自動的にリフレッシュされる。
///
/// - Note: このクラスは内部実装であり、外部には公開されない。
///         FirestoreClient 等の公開APIから透過的に使用される。
public actor AccessTokenProvider {
    /// シングルトンインスタンス
    public static let shared = AccessTokenProvider()

    /// キャッシュされたトークン
    private var cache: TokenCache?

    /// 現在の環境
    private let environment: Environment

    /// HTTPクライアントプロバイダー
    private let httpClientProvider: HTTPClientProvider

    /// 環境種別
    private enum Environment {
        case cloudRun
        case local
        case emulator
    }

    private init() {
        self.httpClientProvider = HTTPClientProvider()
        self.environment = Self.detectEnvironment()
    }

    /// テスト用の初期化（Internal モジュール内でのみ使用可能）
    internal init(httpClientProvider: HTTPClientProvider, forceLocal: Bool = false) {
        self.httpClientProvider = httpClientProvider
        self.environment = forceLocal ? .local : Self.detectEnvironment()
    }

    /// アクセストークンを取得
    ///
    /// キャッシュが有効な場合はキャッシュから返し、
    /// 無効な場合は新しいトークンを取得してキャッシュを更新する。
    ///
    /// - Returns: GCPアクセストークン
    /// - Throws: `GCPAuthError` 取得に失敗した場合
    public func getAccessToken() async throws -> String {
        // キャッシュが有効な場合はそれを返す
        if let cache = cache, cache.isValid {
            return cache.token
        }

        // 新しいトークンを取得
        let (token, expiresIn) = try await fetchToken()
        cache = TokenCache(token: token, expiresIn: expiresIn)
        return token
    }

    /// キャッシュをクリア（テスト用）
    func clearCache() {
        cache = nil
    }

    /// 環境に応じてトークンを取得
    private func fetchToken() async throws -> (token: String, expiresIn: Int) {
        switch environment {
        case .cloudRun:
            let client = MetadataServerClient(httpClientProvider: httpClientProvider)
            return try await client.fetchToken()
        case .local:
            let client = LocalAuthClient()
            let token = try await client.fetchToken()
            // gcloud CLI はexpiresInを返さないので、デフォルト値を設定（55分）
            return (token, 3300)
        case .emulator:
            // エミュレーターモードでは認証不要
            // Firestore エミュレーターは任意のトークンを受け入れる
            return ("owner", 3600)
        }
    }

    /// 実行環境を検出
    private static func detectEnvironment() -> Environment {
        // エミュレーターモードの検出
        // USE_FIREBASE_EMULATOR=true または FIRESTORE_EMULATOR_HOST が設定されている場合
        if ProcessInfo.processInfo.environment["USE_FIREBASE_EMULATOR"] == "true"
            || ProcessInfo.processInfo.environment["FIRESTORE_EMULATOR_HOST"] != nil
        {
            return .emulator
        }

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
