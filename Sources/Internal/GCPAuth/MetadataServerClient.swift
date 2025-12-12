import AsyncHTTPClient
import Foundation
import NIOCore

/// Cloud Run メタデータサーバーからアクセストークンとプロジェクトIDを取得するクライアント
///
/// Cloud Run 環境でのみ動作する。メタデータサーバーは
/// `http://metadata.google.internal` でアクセス可能。
struct MetadataServerClient: Sendable {
    private let tokenURL =
        "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token"
    private let projectIdURL =
        "http://metadata.google.internal/computeMetadata/v1/project/project-id"
    private let httpClientProvider: HTTPClientProvider

    init(httpClientProvider: HTTPClientProvider = HTTPClientProvider()) {
        self.httpClientProvider = httpClientProvider
    }

    /// メタデータサーバーからアクセストークンを取得
    /// - Returns: トークン情報（トークン文字列と有効期間）
    /// - Throws: `GCPAuthError` 取得に失敗した場合
    func fetchToken() async throws -> (token: String, expiresIn: Int) {
        var request = HTTPClientRequest(url: tokenURL)
        request.method = .GET
        request.headers.add(name: "Metadata-Flavor", value: "Google")

        let response: HTTPClientResponse
        do {
            response = try await httpClientProvider.client.execute(request, timeout: .seconds(10))
        } catch {
            throw GCPAuthError.metadataServerUnavailable
        }

        guard response.status == .ok else {
            throw GCPAuthError.tokenFetchFailed("HTTP \(response.status.code)")
        }

        let body = try await response.body.collect(upTo: 1024 * 1024)
        let data = Data(buffer: body)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let accessToken = json["access_token"] as? String,
            let expiresIn = json["expires_in"] as? Int
        else {
            throw GCPAuthError.tokenParseFailed
        }

        return (accessToken, expiresIn)
    }

    /// メタデータサーバーからプロジェクトIDを取得
    /// - Returns: プロジェクトID
    /// - Throws: `GCPAuthError` 取得に失敗した場合
    func fetchProjectId() async throws -> String {
        var request = HTTPClientRequest(url: projectIdURL)
        request.method = .GET
        request.headers.add(name: "Metadata-Flavor", value: "Google")

        let response: HTTPClientResponse
        do {
            response = try await httpClientProvider.client.execute(request, timeout: .seconds(10))
        } catch {
            throw GCPAuthError.metadataServerUnavailable
        }

        guard response.status == .ok else {
            throw GCPAuthError.projectIdFetchFailed("HTTP \(response.status.code)")
        }

        let body = try await response.body.collect(upTo: 1024 * 1024)
        let data = Data(buffer: body)

        guard let projectId = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !projectId.isEmpty
        else {
            throw GCPAuthError.projectIdFetchFailed("Empty project ID returned")
        }

        return projectId
    }
}
