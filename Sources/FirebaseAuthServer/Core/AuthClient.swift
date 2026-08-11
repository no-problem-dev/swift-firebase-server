import Foundation
import Internal

/// Verifies the Firebase ID tokens your clients send, and hands back the identity inside them.
///
/// This is the server side of Firebase Authentication: it never signs a user in, it only decides
/// whether a token presented by a client is genuine and still valid for this project. Google's
/// signing certificates are fetched once and cached, so a steady stream of requests costs no extra
/// network traffic.
///
/// ## Example
///
/// ```swift
/// // Production
/// let config = AuthConfiguration(projectId: "my-project")
/// let authClient = AuthClient(configuration: config)
///
/// // Verify an ID token
/// let token = try await authClient.verifyIDToken(idToken)
/// print("User ID: \(token.uid)")
///
/// // Emulator
/// let emulatorConfig = AuthConfiguration.emulator(projectId: "my-project")
/// let emulatorClient = AuthClient(configuration: emulatorConfig)
/// ```
///
/// ## Using it from Vapor
///
/// ```swift
/// // In a middleware
/// func handle(request: Request, next: Responder) async throws -> Response {
///     guard let authorization = request.headers["Authorization"].first,
///           authorization.hasPrefix("Bearer ") else {
///         throw Abort(.unauthorized, reason: "Missing authorization header")
///     }
///
///     let idToken = String(authorization.dropFirst("Bearer ".count))
///     let verifiedToken = try await authClient.verifyIDToken(idToken)
///
///     // Attach the identity to the request
///     request.auth.login(verifiedToken)
///     return try await next.respond(to: request)
/// }
/// ```
public final class AuthClient: Sendable {
    public let configuration: AuthConfiguration

    private let httpClientProvider: HTTPClientProvider

    private let tokenVerifier: IDTokenVerifier

    // MARK: - Initializers

    /// Creates a client that owns its own HTTP client.
    ///
    /// Prefer ``init(configuration:httpClientProvider:)`` when the process already runs another
    /// Firebase client, so they share one connection pool.
    ///
    /// - Parameter configuration: The project to verify tokens for.
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

    /// Creates a client that shares an existing HTTP client.
    ///
    /// Use this when several Firebase services — Firestore, Storage, Auth — run in the same process,
    /// so they share one connection pool instead of each opening their own.
    ///
    /// - Parameters:
    ///   - configuration: The project to verify tokens for.
    ///   - httpClientProvider: The provider to borrow the HTTP client from.
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

    /// Creates a production client for a project, with the default 30-second timeout.
    /// - Parameter projectId: The Google Cloud project ID.
    public convenience init(projectId: String) {
        self.init(configuration: AuthConfiguration(projectId: projectId))
    }

    // MARK: - Public Methods

    /// Verifies a Firebase ID token and returns the identity it carries.
    ///
    /// - Parameter idToken: The raw JWT sent by the client, without any `Bearer ` prefix.
    /// - Throws: ``AuthError`` on the first check that fails.
    ///
    /// ## What is checked
    ///
    /// 1. The token splits into three dot-separated Base64URL parts.
    /// 2. The header's `alg` is `RS256`.
    /// 3. The claims:
    ///    - `exp`: not past.
    ///    - `iat`: not in the future.
    ///    - `auth_time`: not in the future.
    ///    - `aud`: equal to the project ID.
    ///    - `iss`: equal to `https://securetoken.google.com/{projectId}`.
    ///    - `sub`: a non-empty string, the Firebase UID.
    /// 4. The RS256 signature, against Google's published certificate for the header's `kid`.
    ///
    /// The three time comparisons allow five minutes of clock skew, so a token stays acceptable for
    /// five minutes past `exp`. Claims are checked before the signature.
    ///
    /// ## What is not checked
    ///
    /// Revocation and account-disabled state are not checked; that needs a call to the Firebase Admin
    /// API. Custom claims are not decoded, `nbf` and `typ` are ignored, and the certificate carrying
    /// the public key is not itself validated.
    ///
    /// - Warning: A client built from ``AuthConfiguration/emulator(projectId:host:port:timeout:)``
    ///   skips every check above except that `sub` is non-empty, and accepts unsigned tokens.
    public func verifyIDToken(_ idToken: String) async throws -> VerifiedToken {
        try await tokenVerifier.verify(idToken)
    }

    /// Pulls the token out of an `Authorization` header value and verifies it.
    ///
    /// The scheme must be `Bearer`, matched case-insensitively, followed by a single space and a
    /// non-empty token.
    ///
    /// - Parameter authorizationHeader: The raw header value, such as `Bearer eyJhbGci…`.
    /// - Throws: ``AuthError/tokenMissing`` if the value is empty, ``AuthError/tokenInvalid(reason:)``
    ///   if it is not in `Bearer <token>` form, or whichever ``AuthError`` the verification itself raises.
    ///
    /// ## Example
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

    /// Splits an `Authorization` header value into scheme and token, matching the scheme
    /// case-insensitively and rejecting an empty token.
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
