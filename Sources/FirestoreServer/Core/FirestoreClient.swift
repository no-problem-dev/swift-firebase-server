import AsyncHTTPClient
import Foundation
import Internal

/// Firestore REST APIクライアント
///
/// サーバーサイドSwiftからFirestoreにアクセスするための軽量クライアント。
/// Firebase SDKを使用せず、REST APIを直接呼び出す。
///
/// ## 初期化方法
///
/// ### 自動設定（Cloud Run / ローカル gcloud）
/// ```swift
/// let firestore = try await FirestoreClient(.auto)
/// ```
///
/// ### エミュレーター
/// ```swift
/// let firestore = FirestoreClient(.emulator(projectId: "demo-project"))
/// ```
///
/// ### 明示指定（テストやカスタム認証フロー）
/// ```swift
/// let firestore = FirestoreClient(.explicit(projectId: "my-project", token: accessToken))
/// ```
public final class FirestoreClient: Sendable {
    /// Firestore設定
    public let configuration: FirestoreConfiguration

    /// 認証トークン
    public let token: String

    /// データベースパス
    public var database: DatabasePath {
        configuration.database
    }

    /// HTTPクライアントプロバイダー
    private let httpClientProvider: HTTPClientProvider

    // MARK: - Initialization

    /// 自動設定モードで初期化（async）
    ///
    /// Cloud Run / ローカル gcloud 環境から projectId と token を自動取得する。
    ///
    /// - Parameters:
    ///   - config: `.auto` または `.autoWithDatabase(databaseId:)`
    ///   - keyEncodingStrategy: キーのエンコーディング戦略
    ///   - keyDecodingStrategy: キーのデコーディング戦略
    /// - Throws: `GCPAuthError` 取得に失敗した場合
    public init(
        _ config: GCPConfiguration,
        keyEncodingStrategy: KeyEncodingStrategy = .useDefaultKeys,
        keyDecodingStrategy: KeyDecodingStrategy = .useDefaultKeys
    ) async throws {
        let resolved = try await GCPEnvironment.shared.resolve(config)

        if resolved.isEmulator {
            self.configuration = FirestoreConfiguration.emulator(
                projectId: resolved.projectId,
                databaseId: resolved.databaseId,
                keyEncodingStrategy: keyEncodingStrategy,
                keyDecodingStrategy: keyDecodingStrategy
            )
        } else {
            self.configuration = FirestoreConfiguration(
                projectId: resolved.projectId,
                databaseId: resolved.databaseId,
                keyEncodingStrategy: keyEncodingStrategy,
                keyDecodingStrategy: keyDecodingStrategy
            )
        }
        self.token = resolved.token
        self.httpClientProvider = HTTPClientProvider()
    }

    /// 同期初期化（emulator / explicit のみ）
    ///
    /// - Parameter config: `.emulator(projectId:)` または `.explicit(projectId:token:)`
    public init(_ config: GCPConfiguration) {
        switch config {
        case .auto, .autoWithDatabase:
            fatalError("Use async init for .auto: try await FirestoreClient(.auto)")
        case .emulator(let projectId):
            self.configuration = FirestoreConfiguration.emulator(projectId: projectId)
            self.token = "owner"
        case .explicit(let projectId, let token):
            self.configuration = FirestoreConfiguration(projectId: projectId)
            self.token = token
        }
        self.httpClientProvider = HTTPClientProvider()
    }

    /// 同期初期化（詳細オプション付き）
    ///
    /// キーエンコーディング戦略やエミュレーター設定を細かく指定する場合に使用。
    ///
    /// - Parameters:
    ///   - config: `.emulator(projectId:)` または `.explicit(projectId:token:)`
    ///   - keyEncodingStrategy: キーのエンコーディング戦略
    ///   - keyDecodingStrategy: キーのデコーディング戦略
    ///   - emulatorHost: エミュレーターホスト（エミュレーターモード時のみ有効）
    ///   - emulatorPort: エミュレーターポート（エミュレーターモード時のみ有効）
    public init(
        _ config: GCPConfiguration,
        keyEncodingStrategy: KeyEncodingStrategy = .useDefaultKeys,
        keyDecodingStrategy: KeyDecodingStrategy = .useDefaultKeys,
        emulatorHost: String = "localhost",
        emulatorPort: Int = 8080
    ) {
        switch config {
        case .auto, .autoWithDatabase:
            fatalError("Use async init for .auto: try await FirestoreClient(.auto)")
        case .emulator(let projectId):
            self.configuration = FirestoreConfiguration.emulator(
                projectId: projectId,
                host: emulatorHost,
                port: emulatorPort,
                keyEncodingStrategy: keyEncodingStrategy,
                keyDecodingStrategy: keyDecodingStrategy
            )
            self.token = "owner"
        case .explicit(let projectId, let token):
            self.configuration = FirestoreConfiguration(
                projectId: projectId,
                keyEncodingStrategy: keyEncodingStrategy,
                keyDecodingStrategy: keyDecodingStrategy
            )
            self.token = token
        }
        self.httpClientProvider = HTTPClientProvider()
    }

    // MARK: - Reference生成

    /// ルートコレクションへの参照を取得
    public func collection(_ collectionId: String) -> CollectionReference {
        let path = try! CollectionPath(collectionId)
        return CollectionReference(database: configuration.database, path: path)
    }

    /// ドキュメントへの参照を取得（パス直接指定）
    public func document(_ path: String) throws -> DocumentReference {
        let docPath = try DocumentPath(path)
        return DocumentReference(database: configuration.database, path: docPath)
    }

    // MARK: - Internal

    internal var client: HTTPClient {
        httpClientProvider.client
    }
}
