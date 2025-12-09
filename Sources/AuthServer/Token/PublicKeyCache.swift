import Foundation
import AsyncHTTPClient
import NIOCore
import NIOHTTP1
import Internal

/// Google 公開鍵キャッシュ
///
/// Firebase ID トークンの署名検証に必要な公開鍵を取得・キャッシュする。
/// Cache-Control ヘッダーの max-age に基づいて自動的にキャッシュを更新。
public actor PublicKeyCache {
    /// キャッシュされた公開鍵（kid -> PEM 形式の X.509 証明書）
    private var cachedKeys: [String: String] = [:]

    /// キャッシュの有効期限
    private var cacheExpiry: Date?

    /// HTTP クライアントプロバイダー
    private let httpClientProvider: HTTPClientProvider

    /// 公開鍵エンドポイント
    private let publicKeysURL: URL

    /// タイムアウト
    private let timeout: TimeInterval

    /// デフォルトのキャッシュ有効期間（秒）
    /// Cache-Control ヘッダーが取得できない場合に使用
    private static let defaultCacheDuration: TimeInterval = 3600 // 1時間

    // MARK: - Initializers

    public init(
        httpClientProvider: HTTPClientProvider,
        publicKeysURL: URL = AuthConfiguration.publicKeysURL,
        timeout: TimeInterval = 30
    ) {
        self.httpClientProvider = httpClientProvider
        self.publicKeysURL = publicKeysURL
        self.timeout = timeout
    }

    // MARK: - Public Methods

    /// 指定された kid に対応する公開鍵を取得
    /// - Parameter kid: 鍵ID（JWT ヘッダーの kid クレーム）
    /// - Returns: PEM 形式の X.509 証明書
    /// - Throws: `AuthError.publicKeyNotFound` 指定された kid の鍵が見つからない場合
    public func getPublicKey(for kid: String) async throws -> String {
        // キャッシュが有効な場合はキャッシュから返す
        if let expiry = cacheExpiry, Date() < expiry, let key = cachedKeys[kid] {
            return key
        }

        // キャッシュが無効または kid が見つからない場合は更新
        try await refreshKeys()

        guard let key = cachedKeys[kid] else {
            throw AuthError.publicKeyNotFound(kid: kid)
        }

        return key
    }

    /// キャッシュを強制的に更新
    public func refreshKeys() async throws {
        let (keys, maxAge) = try await fetchPublicKeys()
        cachedKeys = keys
        cacheExpiry = Date().addingTimeInterval(maxAge)
    }

    /// 現在キャッシュされている全ての鍵を取得
    public func getAllKeys() async throws -> [String: String] {
        if let expiry = cacheExpiry, Date() < expiry {
            return cachedKeys
        }

        try await refreshKeys()
        return cachedKeys
    }

    // MARK: - Private Methods

    /// Google エンドポイントから公開鍵を取得
    /// - Returns: 公開鍵マップと max-age 秒数
    private func fetchPublicKeys() async throws -> (keys: [String: String], maxAge: TimeInterval) {
        let client = httpClientProvider.client

        var request = HTTPClientRequest(url: publicKeysURL.absoluteString)
        request.method = .GET
        request.headers.add(name: "Accept", value: "application/json")

        let response: HTTPClientResponse
        do {
            response = try await client.execute(
                request,
                timeout: .seconds(Int64(timeout))
            )
        } catch {
            throw AuthError.publicKeyFetchFailed(underlying: error)
        }

        guard response.status == .ok else {
            throw AuthError.publicKeyFetchFailed(
                underlying: NSError(
                    domain: "AuthServer",
                    code: Int(response.status.code),
                    userInfo: [NSLocalizedDescriptionKey: "HTTP \(response.status.code)"]
                )
            )
        }

        // レスポンスボディを取得
        let body = try await response.body.collect(upTo: 1024 * 1024) // 1MB
        let data = Data(buffer: body)

        // JSON をパース
        let keys: [String: String]
        do {
            keys = try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            throw AuthError.publicKeyFetchFailed(underlying: error)
        }

        // Cache-Control ヘッダーから max-age を取得
        let maxAge = parseMaxAge(from: response.headers)

        return (keys, maxAge)
    }

    /// Cache-Control ヘッダーから max-age を解析
    /// - Parameter headers: HTTP レスポンスヘッダー
    /// - Returns: max-age 秒数（取得できない場合はデフォルト値）
    private func parseMaxAge(from headers: HTTPHeaders) -> TimeInterval {
        guard let cacheControl = headers.first(name: "Cache-Control") else {
            return Self.defaultCacheDuration
        }

        // "max-age=xxxxx" を検索
        let components = cacheControl.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        for component in components {
            if component.lowercased().hasPrefix("max-age=") {
                let valueString = component.dropFirst("max-age=".count)
                if let seconds = TimeInterval(valueString) {
                    return seconds
                }
            }
        }

        return Self.defaultCacheDuration
    }
}
