import AsyncHTTPClient
import Foundation
@_exported import Internal
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

    /// 自動設定モードで初期化（async）
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

    /// 同期初期化（emulator / explicit のみ）
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

    /// ファイルをアップロード
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

    /// ファイルをダウンロード
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

    /// ファイルを削除
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

    /// 複数ファイルを削除
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

    /// オブジェクトのメタデータを取得
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

    /// オブジェクトの公開URLを取得
    public func publicURL(for path: String) -> URL {
        configuration.publicURL(for: path)
    }

    // MARK: - Internal

    internal var client: HTTPClient {
        httpClientProvider.client
    }
}
