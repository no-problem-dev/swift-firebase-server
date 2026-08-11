import Foundation

/// The process-wide source of the GCP project ID and access tokens.
///
/// Decides once, when it is first created, whether it is running on Cloud Run or on a developer
/// machine, then serves credentials from that source:
/// - Cloud Run: the instance metadata server at `metadata.google.internal`.
/// - Local: the gcloud CLI, which needs `gcloud auth application-default login` to have been run.
///
/// Both values are cached in the actor's own state. The project ID is fetched once and kept for
/// the lifetime of the process; the token is replaced lazily, on the first request made once it
/// is within five minutes of expiring. Nothing refreshes in the background, so a client that
/// copies the token when it is created holds that copy until it is created again.
///
/// Actor isolation keeps the cache consistent, but a miss is not coalesced: callers that arrive
/// while the first fetch is still in flight each start their own, and the last one to finish
/// wins the cache slot.
public actor GCPEnvironment {
    /// The instance every client resolves through. Its mode is detected the first time the
    /// instance is touched and is never re-evaluated.
    public static let shared = GCPEnvironment()

    /// Where credentials are read from.
    public enum Mode: Sendable {
        /// Cloud Run, where the instance metadata server answers.
        case cloudRun
        /// A developer machine, where the gcloud CLI answers.
        case local
    }

    /// The mode detected when this instance was created.
    ///
    /// Detection looks only at the Cloud Run variables, so any other Google Cloud compute
    /// environment is treated as local and will shell out to gcloud rather than use its own
    /// metadata server.
    public let mode: Mode

    /// Fetched at most once; there is no expiry on it, only `clearCache()`.
    private var cachedProjectId: String?

    private var tokenCache: TokenCache?

    private let httpClientProvider: HTTPClientProvider

    private init() {
        self.httpClientProvider = HTTPClientProvider()
        self.mode = Self.detectEnvironment()
    }

    /// Creates an instance with a forced mode and an injected HTTP client, skipping detection.
    ///
    /// Lets a test drive either mode, and point the metadata requests at a stub server, without
    /// the surrounding environment deciding for it.
    internal init(httpClientProvider: HTTPClientProvider, mode: Mode) {
        self.httpClientProvider = httpClientProvider
        self.mode = mode
    }

    // MARK: - Public API

    /// Turns a configuration into the concrete project ID and token a client will use.
    ///
    /// The two automatic cases go to the cache, and to the metadata server or gcloud on a miss.
    /// The emulator case returns the placeholder token `"owner"` and the explicit case returns
    /// what the caller passed; neither performs any I/O.
    ///
    /// - Parameter config: The credential source to resolve.
    /// - Throws: `GCPAuthError` when the project ID or the token cannot be obtained. The emulator
    ///   and explicit cases never throw.
    public func resolve(_ config: GCPConfiguration) async throws -> ResolvedGCPConfiguration {
        switch config {
        case .auto:
            let credentials = try await getCredentials()
            return ResolvedGCPConfiguration(
                projectId: credentials.projectId,
                token: credentials.token,
                databaseId: "(default)",
                isEmulator: false
            )

        case .autoWithDatabase(let databaseId):
            let credentials = try await getCredentials()
            return ResolvedGCPConfiguration(
                projectId: credentials.projectId,
                token: credentials.token,
                databaseId: databaseId,
                isEmulator: false
            )

        case .emulator(let projectId):
            return ResolvedGCPConfiguration(
                projectId: projectId,
                token: "owner",
                databaseId: "(default)",
                isEmulator: true
            )

        case .explicit(let projectId, let token):
            return ResolvedGCPConfiguration(
                projectId: projectId,
                token: token,
                databaseId: "(default)",
                isEmulator: false
            )
        }
    }

    /// Fetches the project ID and the access token together.
    ///
    /// The two are started as concurrent child tasks, so on a cold start their round trips
    /// overlap instead of running back to back. Either one failing throws, and the other's result
    /// is discarded.
    ///
    /// - Throws: `GCPAuthError` when either value cannot be obtained.
    public func getCredentials() async throws -> (projectId: String, token: String) {
        async let projectId = getProjectId()
        async let token = getAccessToken()
        return try await (projectId, token)
    }

    /// Returns the project ID, fetching it the first time and caching it afterwards.
    ///
    /// The cached value has no expiry: once a project ID is known it is reused for the lifetime
    /// of the process, and only `clearCache()` drops it.
    ///
    /// - Throws: `GCPAuthError.projectIdFetchFailed` when the metadata server or gcloud cannot
    ///   supply it, or `.gcloudNotAvailable` when gcloud is not installed.
    public func getProjectId() async throws -> String {
        if let cached = cachedProjectId {
            return cached
        }

        let projectId = try await fetchProjectId()
        cachedProjectId = projectId
        return projectId
    }

    /// Returns a cached token, or fetches a new one once the cached one is close to expiring.
    ///
    /// A token counts as expired five minutes before it actually is, so what is handed out is
    /// always good for at least that long. On Cloud Run the lifetime is whatever `expires_in` the
    /// metadata server reports, in practice an hour; locally gcloud reports nothing, so 55
    /// minutes is assumed. After the margin that means a token is reused for roughly 55 minutes
    /// on Cloud Run and 50 minutes locally.
    ///
    /// - Throws: `GCPAuthError.metadataServerUnavailable`, `.tokenFetchFailed` or
    ///   `.tokenParseFailed` on Cloud Run; `.gcloudNotAvailable` or `.gcloudExecutionFailed`
    ///   locally.
    public func getAccessToken() async throws -> String {
        if let cache = tokenCache, cache.isValid {
            return cache.token
        }

        let (token, expiresIn) = try await fetchToken()
        tokenCache = TokenCache(token: token, expiresIn: expiresIn)
        return token
    }

    /// Drops the cached project ID and token so the next call fetches both again.
    ///
    /// The only way to invalidate the project ID, which otherwise never expires. Used by tests.
    public func clearCache() {
        cachedProjectId = nil
        tokenCache = nil
    }

    // MARK: - Private

    /// Reads the project ID from the metadata server, or from `gcloud config get-value project`.
    private func fetchProjectId() async throws -> String {
        switch mode {
        case .cloudRun:
            let client = MetadataServerClient(httpClientProvider: httpClientProvider)
            return try await client.fetchProjectId()
        case .local:
            let client = LocalAuthClient()
            return try await client.fetchProjectId()
        }
    }

    /// Reads a token from the metadata server, or from gcloud's application default credentials.
    ///
    /// The lifetime comes back from the metadata server; locally it has to be assumed.
    private func fetchToken() async throws -> (token: String, expiresIn: Int) {
        switch mode {
        case .cloudRun:
            let client = MetadataServerClient(httpClientProvider: httpClientProvider)
            return try await client.fetchToken()
        case .local:
            let client = LocalAuthClient()
            let token = try await client.fetchToken()
            // gcloud prints no expiry alongside the token, so assume 55 minutes.
            return (token, 3300)
        }
    }

    /// Detects the mode from the environment variables Cloud Run sets.
    ///
    /// Presence alone decides it, and nothing else is examined, so a Compute Engine or GKE
    /// process falls through to the local mode even though it has a metadata server of its own.
    private static func detectEnvironment() -> Mode {
        // K_SERVICE is set automatically by Cloud Run.
        // K_REVISION is likewise specific to Cloud Run.
        if ProcessInfo.processInfo.environment["K_SERVICE"] != nil
            || ProcessInfo.processInfo.environment["K_REVISION"] != nil
        {
            return .cloudRun
        }
        return .local
    }
}
