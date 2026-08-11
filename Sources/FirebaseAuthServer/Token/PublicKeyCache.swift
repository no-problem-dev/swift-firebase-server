import Foundation
import AsyncHTTPClient
import NIOCore
import NIOHTTP1
import Internal

/// Holds Google's Firebase ID token signing certificates, keyed by key ID.
///
/// The whole set of certificates is fetched in one request and kept until the `max-age` from the
/// response's `Cache-Control` header runs out, or for one hour if that header is missing or
/// unparseable. Nothing refreshes in the background: the next lookup after the deadline pays for the
/// refresh, and so does any lookup for a key ID the cache has never seen.
public actor PublicKeyCache {
    /// Key ID to PEM-encoded X.509 certificate, as returned by Google's endpoint.
    private var cachedKeys: [String: String] = [:]

    private var cacheExpiry: Date?

    private let httpClientProvider: HTTPClientProvider

    private let publicKeysURL: URL

    private let timeout: TimeInterval

    /// How long to trust a fetch whose response carried no usable `max-age`, in seconds.
    private static let defaultCacheDuration: TimeInterval = 3600 // 1 hour

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

    /// Returns the certificate for a key ID, fetching Google's key set first if it is stale or if the
    /// key ID is unknown.
    ///
    /// An unrecognised key ID forces a fetch even inside the `max-age` window, which is what lets a
    /// freshly rotated Google key be picked up. It also means a caller feeding in invented key IDs
    /// triggers one network round trip per attempt.
    ///
    /// - Parameter kid: The key ID from the JWT header's `kid` field.
    /// - Returns: A PEM-encoded X.509 certificate that contains the RSA public key.
    /// - Throws: ``AuthError/publicKeyNotFound(kid:)`` if the key ID is still absent after a refresh,
    ///   or ``AuthError/publicKeyFetchFailed(underlying:)`` if the refresh itself failed.
    public func getPublicKey(for kid: String) async throws -> String {
        // Serve from the cache while it is fresh and holds this key ID
        if let expiry = cacheExpiry, Date() < expiry, let key = cachedKeys[kid] {
            return key
        }

        // Stale cache, or an unknown key ID: refresh
        try await refreshKeys()

        guard let key = cachedKeys[kid] else {
            throw AuthError.publicKeyNotFound(kid: kid)
        }

        return key
    }

    /// Fetches Google's key set now, regardless of how fresh the cache is.
    ///
    /// The stored keys are replaced wholesale, so a key Google has dropped disappears here too, and
    /// the expiry restarts from the new response. A failed fetch throws and leaves the previous cache
    /// and its expiry untouched.
    public func refreshKeys() async throws {
        let (keys, maxAge) = try await fetchPublicKeys()
        cachedKeys = keys
        cacheExpiry = Date().addingTimeInterval(maxAge)
    }

    /// Returns every certificate in the key set, refreshing first if the cache has expired.
    public func getAllKeys() async throws -> [String: String] {
        if let expiry = cacheExpiry, Date() < expiry {
            return cachedKeys
        }

        try await refreshKeys()
        return cachedKeys
    }

    // MARK: - Private Methods

    /// Fetches the key set from Google over `GET`.
    ///
    /// Anything other than `200` with a JSON body of key ID to PEM string is an error, including a
    /// transport failure and an unparseable body; all of them surface as
    /// ``AuthError/publicKeyFetchFailed(underlying:)``.
    ///
    /// - Returns: The key set, and the number of seconds it may be cached.
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

        // Read the response body, refusing anything larger than 1 MB
        let body = try await response.body.collect(upTo: 1024 * 1024) // 1MB
        let data = body.toData()

        // Parse the JSON
        let keys: [String: String]
        do {
            keys = try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            throw AuthError.publicKeyFetchFailed(underlying: error)
        }

        // Take max-age from the Cache-Control header
        let maxAge = parseMaxAge(from: response.headers)

        return (keys, maxAge)
    }

    /// Reads the `max-age` directive out of a `Cache-Control` header.
    ///
    /// Only `max-age` is honoured. Other directives, including `no-store` and `must-revalidate`, are
    /// ignored, and a header without a numeric `max-age` falls back to the default duration.
    ///
    /// - Parameter headers: The response headers from the key set fetch.
    /// - Returns: The cache lifetime in seconds.
    private func parseMaxAge(from headers: HTTPHeaders) -> TimeInterval {
        guard let cacheControl = headers.first(name: "Cache-Control") else {
            return Self.defaultCacheDuration
        }

        // Look for "max-age=xxxxx"
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
