import AsyncHTTPClient
import Foundation
import Internal
import NIOCore
import NIOHTTP1

/// Cloud Storage REST APIクライアント
///
/// サーバーサイドSwiftからCloud Storageにアクセスするための軽量クライアント。
/// Firebase SDKを使用せず、REST APIを直接呼び出す。
///
/// ## 初期化方法
///
/// ### 自動設定（Cloud Run / ローカル gcloud）
/// ```swift
/// let storage = try await StorageClient(.auto, bucket: "my-bucket")
/// ```
///
/// ### エミュレーター
/// ```swift
/// let storage = StorageClient(.emulator(projectId: "demo-project"), bucket: "my-bucket")
/// ```
///
/// ### 明示指定
/// ```swift
/// let storage = StorageClient(.explicit(projectId: "my-project", token: accessToken), bucket: "my-bucket")
/// ```
public final class StorageClient: Sendable {
    /// 設定
    public let configuration: StorageConfiguration

    /// 認証トークン
    public let token: String

    /// HTTPクライアントプロバイダー
    private let httpClientProvider: HTTPClientProvider

    // MARK: - Initialization

    /// 自動設定モードで初期化する（async）。
    ///
    /// Cloud Run または gcloud ADC から認証情報を自動取得する。`.emulator` / `.explicit` の場合も使用可能。
    /// - Parameters:
    ///   - config: GCP 設定
    ///   - bucket: アクセスするバケット名
    /// - Throws: 認証情報の解決に失敗した場合
    public init(_ config: GCPConfiguration, bucket: String) async throws {
        let resolved = try await GCPEnvironment.shared.resolve(config)

        if resolved.isEmulator {
            self.configuration = StorageConfiguration.emulator(
                projectId: resolved.projectId,
                bucket: bucket
            )
        } else {
            self.configuration = StorageConfiguration(
                projectId: resolved.projectId,
                bucket: bucket
            )
        }
        self.token = resolved.token
        self.httpClientProvider = HTTPClientProvider()
    }

    /// 同期初期化（`.emulator` / `.explicit` 専用）。
    ///
    /// `.auto` を渡すと fatalError になる。非同期認証が不要な場合に使用する。
    /// - Parameters:
    ///   - config: GCP 設定（`.emulator` または `.explicit` のみ有効）
    ///   - bucket: アクセスするバケット名
    public init(_ config: GCPConfiguration, bucket: String) {
        switch config {
        case .auto, .autoWithDatabase:
            fatalError("Use async init for .auto: try await StorageClient(.auto, bucket:)")
        case .emulator(let projectId):
            self.configuration = StorageConfiguration.emulator(projectId: projectId, bucket: bucket)
            self.token = "owner"
        case .explicit(let projectId, let token):
            self.configuration = StorageConfiguration(projectId: projectId, bucket: bucket)
            self.token = token
        }
        self.httpClientProvider = HTTPClientProvider()
    }

    // MARK: - Public API

    /// ファイルをアップロードし、アップロード結果のメタデータを返す。
    /// - Parameters:
    ///   - data: アップロードするバイナリデータ
    ///   - path: バケット内のオブジェクトパス（例: `"images/user123.jpg"`）
    ///   - contentType: MIME タイプ（例: `"image/jpeg"`）
    /// - Returns: アップロードされたオブジェクトのメタデータ
    /// - Throws: `StorageError`（HTTP エラー・JSON パース失敗を含む）
    public func upload(
        data: Data,
        path: String,
        contentType: String
    ) async throws -> StorageObject {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let url = "\(configuration.uploadBaseURL)/b/\(configuration.bucket)/o?uploadType=media&name=\(encodedPath)"

        var request = HTTPClientRequest(url: url)
        request.method = .POST
        request.headers.add(name: "Authorization", value: "Bearer \(token)")
        request.headers.add(name: "Content-Type", value: contentType)
        request.headers.add(name: "Content-Length", value: String(data.count))
        request.body = .bytes(ByteBuffer(data: data))

        let response = try await httpClientProvider.client.execute(
            request,
            timeout: .seconds(Int64(configuration.timeout))
        )
        let body = try await response.body.collect(upTo: 10 * 1024 * 1024)

        guard response.status == .ok else {
            throw StorageError.fromHTTPResponse(
                statusCode: Int(response.status.code),
                body: body.toData(),
                path: path
            )
        }

        let bodyData = body.toData()
        guard let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            let bodyString = String(data: bodyData, encoding: .utf8) ?? "Unable to decode body"
            throw StorageError.invalidArgument(message: "Invalid JSON response from server. Body: \(bodyString)")
        }

        guard let storageObject = StorageObject.fromJSON(json) else {
            let jsonString = String(data: bodyData, encoding: .utf8) ?? "Unable to decode JSON"
            throw StorageError.invalidArgument(message: "Failed to parse StorageObject from JSON. JSON: \(jsonString)")
        }

        return storageObject
    }

    /// ファイルをダウンロードし、バイナリデータを返す（最大 100 MB）。
    /// - Parameter path: バケット内のオブジェクトパス
    /// - Returns: ダウンロードしたバイナリデータ
    /// - Throws: `StorageError`（オブジェクトが存在しない場合は `.notFound`）
    public func download(path: String) async throws -> Data {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let url = "\(configuration.baseURL)/b/\(configuration.bucket)/o/\(encodedPath)?alt=media"

        var request = HTTPClientRequest(url: url)
        request.method = .GET
        request.headers.add(name: "Authorization", value: "Bearer \(token)")

        let response = try await httpClientProvider.client.execute(
            request,
            timeout: .seconds(Int64(configuration.timeout))
        )
        let body = try await response.body.collect(upTo: 100 * 1024 * 1024)

        guard response.status == .ok else {
            throw StorageError.fromHTTPResponse(
                statusCode: Int(response.status.code),
                body: body.toData(),
                path: path
            )
        }

        return body.toData()
    }

    /// 指定パスのファイルを削除する。
    /// - Parameter path: バケット内のオブジェクトパス
    /// - Throws: `StorageError`（オブジェクトが存在しない場合は `.notFound`）
    public func delete(path: String) async throws {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let url = "\(configuration.baseURL)/b/\(configuration.bucket)/o/\(encodedPath)"

        var request = HTTPClientRequest(url: url)
        request.method = .DELETE
        request.headers.add(name: "Authorization", value: "Bearer \(token)")

        let response = try await httpClientProvider.client.execute(
            request,
            timeout: .seconds(Int64(configuration.timeout))
        )

        guard response.status == .noContent || response.status == .ok else {
            let body = try await response.body.collect(upTo: 1 * 1024 * 1024)
            throw StorageError.fromHTTPResponse(
                statusCode: Int(response.status.code),
                body: body.toData(),
                path: path
            )
        }
    }

    /// 複数ファイルを順次削除し、失敗したパスとエラーを返す。
    ///
    /// 個々の削除失敗はスローせず、失敗情報をまとめて返す。全件成功した場合は空配列を返す。
    /// - Parameter paths: 削除するオブジェクトパスの配列
    /// - Returns: 失敗した `(path, error)` タプルの配列（順不同）
    public func deleteMultiple(paths: [String]) async -> [(path: String, error: StorageError)] {
        var failures: [(path: String, error: StorageError)] = []

        for path in paths {
            do {
                try await delete(path: path)
            } catch let error as StorageError {
                failures.append((path: path, error: error))
            } catch {
                failures.append((path: path, error: .unknown(statusCode: -1, message: error.localizedDescription)))
            }
        }

        return failures
    }

    /// 指定パスのオブジェクトメタデータを取得する。
    /// - Parameter path: バケット内のオブジェクトパス
    /// - Returns: オブジェクトのメタデータ（サイズ・コンテンツタイプ・ハッシュ等）
    /// - Throws: `StorageError`（オブジェクトが存在しない場合は `.notFound`）
    public func getMetadata(path: String) async throws -> StorageObject {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let url = "\(configuration.baseURL)/b/\(configuration.bucket)/o/\(encodedPath)"

        var request = HTTPClientRequest(url: url)
        request.method = .GET
        request.headers.add(name: "Authorization", value: "Bearer \(token)")

        let response = try await httpClientProvider.client.execute(
            request,
            timeout: .seconds(Int64(configuration.timeout))
        )
        let body = try await response.body.collect(upTo: 1 * 1024 * 1024)

        guard response.status == .ok else {
            throw StorageError.fromHTTPResponse(
                statusCode: Int(response.status.code),
                body: body.toData(),
                path: path
            )
        }

        guard
            let json = try JSONSerialization.jsonObject(with: body.toData()) as? [String: Any],
            let storageObject = StorageObject.fromJSON(json)
        else {
            throw StorageError.invalidArgument(message: "Invalid response from server")
        }

        return storageObject
    }

    /// オブジェクトの公開 URL を返す（エミュレーター環境ではローカル URL）。
    /// - Parameter path: バケット内のオブジェクトパス
    /// - Returns: 公開アクセス可能な URL
    public func publicURL(for path: String) -> URL {
        configuration.publicURL(for: path)
    }

    // MARK: - Internal

    internal var client: HTTPClient {
        httpClientProvider.client
    }
}
