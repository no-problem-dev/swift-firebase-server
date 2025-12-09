import Foundation
import Internal

/// Firebase Auth クライアント
///
/// Firebase ID トークンを検証し、ユーザー情報を取得するためのクライアント。
/// サーバーサイドで使用し、クライアントから送信された ID トークンを検証する。
///
/// ## 使用例
///
/// ```swift
/// // 本番環境
/// let config = AuthConfiguration(projectId: "my-project")
/// let authClient = AuthClient(configuration: config)
///
/// // ID トークンを検証
/// let token = try await authClient.verifyIDToken(idToken)
/// print("User ID: \(token.uid)")
///
/// // エミュレーター環境
/// let emulatorConfig = AuthConfiguration.emulator(projectId: "my-project")
/// let emulatorClient = AuthClient(configuration: emulatorConfig)
/// ```
///
/// ## Vapor での使用例
///
/// ```swift
/// // ミドルウェアでの使用
/// func handle(request: Request, next: Responder) async throws -> Response {
///     guard let authorization = request.headers["Authorization"].first,
///           authorization.hasPrefix("Bearer ") else {
///         throw Abort(.unauthorized, reason: "Missing authorization header")
///     }
///
///     let idToken = String(authorization.dropFirst("Bearer ".count))
///     let verifiedToken = try await authClient.verifyIDToken(idToken)
///
///     // ユーザーIDをリクエストに保存
///     request.auth.login(verifiedToken)
///     return try await next.respond(to: request)
/// }
/// ```
public final class AuthClient: Sendable {
    /// 設定
    public let configuration: AuthConfiguration

    /// HTTP クライアントプロバイダー
    private let httpClientProvider: HTTPClientProvider

    /// ID トークン検証器
    private let tokenVerifier: IDTokenVerifier

    // MARK: - Initializers

    /// 設定を指定して初期化（HTTPClient を内部で作成）
    /// - Parameter configuration: Auth 設定
    public init(configuration: AuthConfiguration) {
        self.configuration = configuration
        self.httpClientProvider = HTTPClientProvider()

        let publicKeyCache = PublicKeyCache(
            httpClientProvider: self.httpClientProvider,
            timeout: configuration.timeout
        )

        self.tokenVerifier = IDTokenVerifier(
            configuration: configuration,
            publicKeyCache: publicKeyCache
        )
    }

    /// 設定と HTTP クライアントプロバイダーを指定して初期化
    ///
    /// 複数の Firebase サービス（Firestore, Storage, Auth）で
    /// HTTPClient を共有する場合に使用。
    ///
    /// - Parameters:
    ///   - configuration: Auth 設定
    ///   - httpClientProvider: 共有 HTTPClientProvider
    public init(
        configuration: AuthConfiguration,
        httpClientProvider: HTTPClientProvider
    ) {
        self.configuration = configuration
        self.httpClientProvider = httpClientProvider

        let publicKeyCache = PublicKeyCache(
            httpClientProvider: httpClientProvider,
            timeout: configuration.timeout
        )

        self.tokenVerifier = IDTokenVerifier(
            configuration: configuration,
            publicKeyCache: publicKeyCache
        )
    }

    /// プロジェクトIDのみを指定して初期化（簡易版）
    /// - Parameter projectId: Google Cloud プロジェクトID
    public convenience init(projectId: String) {
        self.init(configuration: AuthConfiguration(projectId: projectId))
    }

    // MARK: - Public Methods

    /// Firebase ID トークンを検証
    ///
    /// クライアントから送信された ID トークンを検証し、
    /// 検証が成功した場合はユーザー情報を含む `VerifiedToken` を返す。
    ///
    /// - Parameter idToken: Firebase ID トークン文字列
    /// - Returns: 検証済みトークン
    /// - Throws: `AuthError` 検証に失敗した場合
    ///
    /// ## 検証内容
    ///
    /// 1. JWT 形式の検証（3パートに分割可能か）
    /// 2. アルゴリズムの検証（RS256 であるか）
    /// 3. クレームの検証:
    ///    - `exp`: 有効期限が未来であること
    ///    - `iat`: 発行時刻が過去であること
    ///    - `auth_time`: 認証時刻が過去であること
    ///    - `aud`: プロジェクトID と一致
    ///    - `iss`: `https://securetoken.google.com/{projectId}` と一致
    ///    - `sub`: 非空文字列（Firebase UID）
    /// 4. 署名の検証（Google 公開鍵で RS256 検証）
    public func verifyIDToken(_ idToken: String) async throws -> VerifiedToken {
        try await tokenVerifier.verify(idToken)
    }

    /// Authorization ヘッダーから ID トークンを抽出して検証
    ///
    /// `Bearer {token}` 形式のヘッダー値からトークンを抽出し、検証する。
    ///
    /// - Parameter authorizationHeader: Authorization ヘッダーの値
    /// - Returns: 検証済みトークン
    /// - Throws: `AuthError.tokenMissing` ヘッダーが空の場合
    /// - Throws: `AuthError.tokenInvalid` Bearer 形式でない場合
    /// - Throws: その他の `AuthError` 検証に失敗した場合
    ///
    /// ## 使用例
    ///
    /// ```swift
    /// let authHeader = request.headers["Authorization"].first ?? ""
    /// let token = try await authClient.verifyAuthorizationHeader(authHeader)
    /// ```
    public func verifyAuthorizationHeader(_ authorizationHeader: String) async throws -> VerifiedToken {
        let idToken = try extractBearerToken(from: authorizationHeader)
        return try await verifyIDToken(idToken)
    }

    // MARK: - Private Methods

    /// Authorization ヘッダーから Bearer トークンを抽出
    private func extractBearerToken(from header: String) throws -> String {
        guard !header.isEmpty else {
            throw AuthError.tokenMissing
        }

        let parts = header.split(separator: " ", maxSplits: 1)

        guard parts.count == 2,
              parts[0].lowercased() == "bearer" else {
            throw AuthError.tokenInvalid(reason: "Expected 'Bearer <token>' format")
        }

        let token = String(parts[1])

        guard !token.isEmpty else {
            throw AuthError.tokenInvalid(reason: "Token is empty")
        }

        return token
    }
}
