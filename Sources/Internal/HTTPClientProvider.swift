import AsyncHTTPClient
import Foundation
import NIOCore

/// HTTPクライアントを管理するプロバイダー
///
/// FirestoreServer, StorageServer など複数のサービスで共有可能な
/// HTTPクライアント管理機能を提供する。
public final class HTTPClientProvider: Sendable {
    /// HTTPクライアント
    private let httpClient: HTTPClient

    /// 所有権フラグ（自身で作成したクライアントかどうか）
    private let ownsClient: Bool

    /// シングルトンEventLoopGroupを使用して初期化
    public init() {
        self.httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        self.ownsClient = true
    }

    /// 既存のHTTPClientを使用して初期化
    /// - Parameter client: 既存のHTTPClient（ライフサイクルは呼び出し側が管理）
    public init(client: HTTPClient) {
        self.httpClient = client
        self.ownsClient = false
    }

    deinit {
        if ownsClient {
            try? httpClient.syncShutdown()
        }
    }

    /// HTTPクライアントへのアクセス
    public var client: HTTPClient {
        httpClient
    }
}
