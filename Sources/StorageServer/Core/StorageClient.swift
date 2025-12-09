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
/// 使用例:
/// ```swift
/// let storage = StorageClient(projectId: "my-project", bucket: "my-bucket")
///
/// // アップロード
/// let object = try await storage.upload(
///     data: imageData,
///     path: "images/photo.jpg",
///     contentType: "image/jpeg",
///     authorization: idToken
/// )
///
/// // ダウンロード
/// let data = try await storage.download(path: "images/photo.jpg", authorization: idToken)
///
/// // 削除
/// try await storage.delete(path: "images/photo.jpg", authorization: idToken)
/// ```
public final class StorageClient: Sendable {
    /// 設定
    public let configuration: StorageConfiguration

    /// HTTPクライアントプロバイダー
    private let httpClientProvider: HTTPClientProvider

    /// 本番環境用の初期化
    /// - Parameters:
    ///   - projectId: Google CloudプロジェクトID
    ///   - bucket: バケット名（例: "my-project.appspot.com"）
    public convenience init(projectId: String, bucket: String) {
        let config = StorageConfiguration(projectId: projectId, bucket: bucket)
        self.init(configuration: config)
    }

    /// 設定を指定して初期化
    /// - Parameter configuration: Storage設定
    public init(configuration: StorageConfiguration) {
        self.configuration = configuration
        self.httpClientProvider = HTTPClientProvider()
    }

    /// 設定と既存のHTTPClientProviderを指定して初期化
    /// - Parameters:
    ///   - configuration: Storage設定
    ///   - httpClientProvider: 既存のHTTPClientProvider
    public init(configuration: StorageConfiguration, httpClientProvider: HTTPClientProvider) {
        self.configuration = configuration
        self.httpClientProvider = httpClientProvider
    }

    // MARK: - Public API

    /// ファイルをアップロード
    /// - Parameters:
    ///   - data: アップロードするデータ
    ///   - path: 保存先パス（例: "images/photo.jpg"）
    ///   - contentType: コンテンツタイプ（例: "image/jpeg"）
    ///   - authorization: 認証トークン
    /// - Returns: アップロードされたオブジェクトのメタデータ
    public func upload(
        data: Data,
        path: String,
        contentType: String,
        authorization: String
    ) async throws -> StorageObject {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let url = "\(configuration.uploadBaseURL)/b/\(configuration.bucket)/o?uploadType=media&name=\(encodedPath)"

        var request = HTTPClientRequest(url: url)
        request.method = .POST
        request.headers.add(name: "Authorization", value: "Bearer \(authorization)")
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
                body: Data(buffer: body),
                path: path
            )
        }

        let bodyData = Data(buffer: body)
        guard
            let json = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
            let storageObject = StorageObject.fromJSON(json)
        else {
            throw StorageError.invalidArgument(message: "Invalid response from server")
        }

        return storageObject
    }

    /// ファイルをダウンロード
    /// - Parameters:
    ///   - path: ダウンロードするオブジェクトのパス
    ///   - authorization: 認証トークン
    /// - Returns: ファイルデータ
    public func download(
        path: String,
        authorization: String
    ) async throws -> Data {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let url = "\(configuration.baseURL)/b/\(configuration.bucket)/o/\(encodedPath)?alt=media"

        var request = HTTPClientRequest(url: url)
        request.method = .GET
        request.headers.add(name: "Authorization", value: "Bearer \(authorization)")

        let response = try await httpClientProvider.client.execute(
            request,
            timeout: .seconds(Int64(configuration.timeout))
        )
        let body = try await response.body.collect(upTo: 100 * 1024 * 1024) // 100MB max

        guard response.status == .ok else {
            throw StorageError.fromHTTPResponse(
                statusCode: Int(response.status.code),
                body: Data(buffer: body),
                path: path
            )
        }

        return Data(buffer: body)
    }

    /// ファイルを削除
    /// - Parameters:
    ///   - path: 削除するオブジェクトのパス
    ///   - authorization: 認証トークン
    public func delete(
        path: String,
        authorization: String
    ) async throws {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let url = "\(configuration.baseURL)/b/\(configuration.bucket)/o/\(encodedPath)"

        var request = HTTPClientRequest(url: url)
        request.method = .DELETE
        request.headers.add(name: "Authorization", value: "Bearer \(authorization)")

        let response = try await httpClientProvider.client.execute(
            request,
            timeout: .seconds(Int64(configuration.timeout))
        )

        // 204 No Content or 200 OK
        guard response.status == .noContent || response.status == .ok else {
            let body = try await response.body.collect(upTo: 1 * 1024 * 1024)
            throw StorageError.fromHTTPResponse(
                statusCode: Int(response.status.code),
                body: Data(buffer: body),
                path: path
            )
        }
    }

    /// 複数ファイルを削除
    /// - Parameters:
    ///   - paths: 削除するオブジェクトのパス配列
    ///   - authorization: 認証トークン
    /// - Returns: 削除に失敗したパスとエラーの配列（全て成功した場合は空）
    public func deleteMultiple(
        paths: [String],
        authorization: String
    ) async throws -> [(path: String, error: StorageError)] {
        var failures: [(path: String, error: StorageError)] = []

        for path in paths {
            do {
                try await delete(path: path, authorization: authorization)
            } catch let error as StorageError {
                failures.append((path: path, error: error))
            }
        }

        return failures
    }

    /// オブジェクトのメタデータを取得
    /// - Parameters:
    ///   - path: オブジェクトのパス
    ///   - authorization: 認証トークン
    /// - Returns: オブジェクトのメタデータ
    public func getMetadata(
        path: String,
        authorization: String
    ) async throws -> StorageObject {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let url = "\(configuration.baseURL)/b/\(configuration.bucket)/o/\(encodedPath)"

        var request = HTTPClientRequest(url: url)
        request.method = .GET
        request.headers.add(name: "Authorization", value: "Bearer \(authorization)")

        let response = try await httpClientProvider.client.execute(
            request,
            timeout: .seconds(Int64(configuration.timeout))
        )
        let body = try await response.body.collect(upTo: 1 * 1024 * 1024)

        guard response.status == .ok else {
            throw StorageError.fromHTTPResponse(
                statusCode: Int(response.status.code),
                body: Data(buffer: body),
                path: path
            )
        }

        let bodyData = Data(buffer: body)
        guard
            let json = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
            let storageObject = StorageObject.fromJSON(json)
        else {
            throw StorageError.invalidArgument(message: "Invalid response from server")
        }

        return storageObject
    }

    /// オブジェクトの公開URLを取得
    /// - Parameter path: オブジェクトのパス
    /// - Returns: 公開URL
    public func publicURL(for path: String) -> URL {
        configuration.publicURL(for: path)
    }

    // MARK: - Internal

    /// HTTPクライアントへのアクセス（内部用）
    internal var client: HTTPClient {
        httpClientProvider.client
    }
}
