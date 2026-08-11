import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Internal

/// Performs privileged Firebase Auth user management through the Identity Toolkit REST API.
///
/// Where ``AuthClient`` only inspects a token a client presented, this client acts on the user
/// directory itself, so it needs service account authority: outside the emulator it takes an access
/// token from the ambient GCP environment — the metadata server on Cloud Run, or local `gcloud`
/// credentials — rather than from anything the caller passes in.
///
/// ## Example
///
/// ```swift
/// // Production (Cloud Run, or local gcloud)
/// let adminClient = AuthAdminClient(projectId: "my-project")
///
/// // Delete a user
/// try await adminClient.deleteUser(uid: "user-123")
///
/// // Emulator
/// let emulatorClient = AuthAdminClient.emulator(projectId: "demo-project")
/// try await emulatorClient.deleteUser(uid: "user-123")
/// ```
public final class AuthAdminClient: Sendable {
    public let projectId: String

    private let httpClientProvider: HTTPClientProvider

    /// The emulator to talk to, or `nil` to talk to the production Identity Toolkit.
    private let emulatorConfig: EmulatorSettings?

    private struct EmulatorSettings: Sendable {
        let host: String
        let port: Int
    }

    // MARK: - Initializers

    /// Creates a client against the production Identity Toolkit API.
    ///
    /// Every call takes a fresh service account access token from the GCP environment the process
    /// runs in, so nothing about credentials is passed here.
    ///
    /// - Parameter projectId: The Google Cloud project ID.
    public init(projectId: String) {
        self.projectId = projectId
        self.httpClientProvider = HTTPClientProvider()
        self.emulatorConfig = nil
    }

    /// Creates a production client alongside an existing HTTP client provider.
    ///
    /// - Parameters:
    ///   - projectId: The Google Cloud project ID.
    ///   - httpClientProvider: A provider shared with the other Firebase clients in the process.
    ///
    /// - Note: The Admin API requests go out over `URLSession.shared`, so passing a provider here does
    ///   not put them on its connection pool.
    public init(projectId: String, httpClientProvider: HTTPClientProvider) {
        self.projectId = projectId
        self.httpClientProvider = httpClientProvider
        self.emulatorConfig = nil
    }

    /// Creates a client against a local Firebase Auth emulator, authenticating with the emulator's
    /// `owner` token instead of real credentials.
    ///
    /// - Parameters:
    ///   - projectId: The project ID the emulator was started with.
    ///   - host: The emulator host. Defaults to `localhost`.
    ///   - port: The emulator port. Defaults to 9099.
    public static func emulator(
        projectId: String,
        host: String = EmulatorConfig.defaultHost,
        port: Int = AuthConfiguration.defaultEmulatorPort
    ) -> AuthAdminClient {
        AuthAdminClient(
            projectId: projectId,
            emulatorConfig: EmulatorSettings(host: host, port: port)
        )
    }

    private init(projectId: String, emulatorConfig: EmulatorSettings) {
        self.projectId = projectId
        self.httpClientProvider = HTTPClientProvider()
        self.emulatorConfig = emulatorConfig
    }

    // MARK: - Public Methods

    /// Deletes a user account from Firebase Auth.
    ///
    /// Sends `POST /v1/accounts:delete` to the Identity Toolkit with the UID as `localId`. The account
    /// and its sign-in identities are gone for good; there is no undo and no soft-delete window.
    ///
    /// - Parameter uid: The Firebase Auth UID of the account to delete.
    /// - Throws: ``AuthError/adminAPIFailed(statusCode:message:)`` for any error the API reports, or
    ///   ``AuthError/deleteUserFailed(reason:)`` if the request could not be formed or the reply was
    ///   not an HTTP response.
    ///
    /// ## Notes
    ///
    /// - Deleting a UID that does not exist succeeds, so the call is safe to retry. That rests on the
    ///   API answering with the message `USER_NOT_FOUND`; any other wording surfaces as an error.
    /// - Only the Auth record goes. Documents in Firestore and objects in Cloud Storage that belong to
    ///   the user have to be deleted separately.
    public func deleteUser(uid: String) async throws {
        let url = try buildDeleteUserURL()
        let token = try await getAccessToken()

        try await executeDelete(url: url, token: token, uid: uid)
    }

    // MARK: - Private Methods

    /// Builds the `accounts:delete` endpoint URL for either the emulator or production.
    private func buildDeleteUserURL() throws -> URL {
        let baseURL: String
        if let emulator = emulatorConfig {
            // Emulator: http://{host}:{port}/identitytoolkit.googleapis.com/v1/accounts:delete
            baseURL = "http://\(emulator.host):\(emulator.port)/identitytoolkit.googleapis.com/v1"
        } else {
            // Production: https://identitytoolkit.googleapis.com/v1
            baseURL = "https://identitytoolkit.googleapis.com/v1"
        }

        let urlString = "\(baseURL)/accounts:delete"
        guard let url = URL(string: urlString) else {
            throw AuthError.deleteUserFailed(reason: "Invalid URL: \(urlString)")
        }
        return url
    }

    /// Returns the bearer token for an Admin API call: the emulator's fixed `owner` token, or a
    /// service account token from the GCP environment.
    private func getAccessToken() async throws -> String {
        if emulatorConfig != nil {
            // The emulator accepts the literal "owner" token
            return "owner"
        }
        // In production, take the token from the GCP environment
        return try await GCPEnvironment.shared.getAccessToken()
    }

    /// Sends the deletion request and maps the reply.
    ///
    /// Despite the name, this is an HTTP `POST` to `accounts:delete`. Only `200` counts as success,
    /// with the one exception that an error body reading `USER_NOT_FOUND` is treated as success so
    /// that repeated deletions stay idempotent.
    private func executeDelete(url: URL, token: String, uid: String) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // The Identity Toolkit API names the user with `localId`, not `uid`
        let body: [String: Any] = ["localId": uid]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.deleteUserFailed(reason: "Invalid response type")
        }

        // Success: 200
        switch httpResponse.statusCode {
        case 200:
            return // success

        default:
            // Dig the message out of the error body
            let message: String
            if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorResponse["error"] as? [String: Any],
               let errorMessage = error["message"] as? String {
                // Count USER_NOT_FOUND as success, so deleting twice is harmless
                if errorMessage == "USER_NOT_FOUND" {
                    return
                }
                message = errorMessage
            } else {
                message = String(data: data, encoding: .utf8) ?? "Unknown error"
            }
            throw AuthError.adminAPIFailed(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }
    }
}
