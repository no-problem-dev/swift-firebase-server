import AsyncHTTPClient
import Foundation
import NIOCore

/// Reads the access token and project ID from the GCP instance metadata server.
///
/// Only works where that server exists, at `http://metadata.google.internal`, which in this
/// package means Cloud Run. Both requests carry the `Metadata-Flavor: Google` header the server
/// demands and give up after ten seconds.
struct MetadataServerClient: Sendable {
    private let tokenURL =
        "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token"
    private let projectIdURL =
        "http://metadata.google.internal/computeMetadata/v1/project/project-id"
    private let httpClientProvider: HTTPClientProvider

    init(httpClientProvider: HTTPClientProvider = HTTPClientProvider()) {
        self.httpClientProvider = httpClientProvider
    }

    /// Fetches an access token for the instance's default service account.
    ///
    /// The token carries whatever scopes that service account was granted, so what it can reach
    /// is decided by IAM rather than by anything here. The response body is read up to 1 MiB.
    ///
    /// - Returns: The token, and the seconds it stays valid as reported by the server.
    /// - Throws: `GCPAuthError.metadataServerUnavailable` if the request itself fails,
    ///   `.tokenFetchFailed` on any status other than 200, or `.tokenParseFailed` if
    ///   `access_token` or `expires_in` is missing from the body.
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

    /// Fetches the ID of the project this instance runs in.
    ///
    /// The response is plain text rather than JSON, and is trimmed of surrounding whitespace.
    ///
    /// - Throws: `GCPAuthError.metadataServerUnavailable` if the request itself fails, or
    ///   `.projectIdFetchFailed` on any status other than 200 or an empty body.
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
