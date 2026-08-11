import Foundation

/// Where a Firebase service client gets its project ID and access token from.
///
/// The cases are exclusive, and each one decides which client initializer you can use: the two
/// automatic cases have to fetch credentials, so they need the async initializer, while the
/// emulator and explicit cases resolve without touching the network and work with the
/// synchronous one.
///
/// Examples:
/// ```swift
/// // Cloud Run / local gcloud: everything is resolved for you
/// let firestore = try await FirestoreClient(.auto)
///
/// // Emulator: only the project ID matters
/// let firestore = FirestoreClient(.emulator(projectId: "demo-project"))
///
/// // Explicit: you pass both (tests, or your own auth flow)
/// let firestore = FirestoreClient(.explicit(projectId: "my-project", token: accessToken))
/// ```
public enum GCPConfiguration: Sendable {
    /// Read the project ID and access token from whatever environment the process is running in.
    ///
    /// Which environment that is comes down to the `K_SERVICE` and `K_REVISION` variables Cloud
    /// Run sets. If either is present, both values come from the instance metadata server;
    /// otherwise both come from the gcloud CLI on the local machine. No other variable is
    /// consulted, so `GOOGLE_APPLICATION_CREDENTIALS`, `GOOGLE_CLOUD_PROJECT`, `GCLOUD_PROJECT`
    /// and `FIRESTORE_EMULATOR_HOST` have no effect here.
    ///
    /// - Note: Only the async client initializer accepts this case; the synchronous one traps.
    case auto

    /// The same as `auto`, but aimed at a named Firestore database.
    ///
    /// - Parameter databaseId: The database to use instead of `"(default)"`. Cloud Storage
    ///   ignores it.
    case autoWithDatabase(databaseId: String)

    /// Talk to the Firebase Emulator Suite.
    ///
    /// Nothing is fetched and no credential source is contacted: the token is the literal string
    /// `"owner"`, which the emulator accepts in place of a real one. Selecting the emulator is
    /// always this explicit; `FIRESTORE_EMULATOR_HOST` is not read.
    ///
    /// - Parameter projectId: The project the emulator scopes data under, for example
    ///   `"demo-project"`. It does not have to exist in Google Cloud.
    case emulator(projectId: String)

    /// Supply the project ID and the token yourself.
    ///
    /// Use it for a user's ID token, for a token minted by your own auth flow, or in tests. The
    /// token is sent verbatim as the bearer credential and is never refreshed, so a client that
    /// lives longer than the token starts failing with 401 until it is created again.
    ///
    /// - Parameters:
    ///   - projectId: The Google Cloud project to address.
    ///   - token: The value sent in the `Authorization: Bearer` header.
    case explicit(projectId: String, token: String)

    // MARK: - Computed Properties

    /// The Firestore database this configuration targets.
    ///
    /// Only `autoWithDatabase` can name one; every other case, the emulator included, resolves
    /// to `"(default)"`.
    var databaseId: String {
        switch self {
        case .autoWithDatabase(let databaseId):
            return databaseId
        default:
            return "(default)"
        }
    }

    var isEmulator: Bool {
        switch self {
        case .emulator:
            return true
        default:
            return false
        }
    }

    /// True for both automatic cases, which are the ones that need the async initializer and a
    /// credential fetch.
    var isAuto: Bool {
        switch self {
        case .auto, .autoWithDatabase:
            return true
        default:
            return false
        }
    }
}

// MARK: - Resolved Configuration

/// The concrete credentials a configuration resolved to.
///
/// A snapshot, not a live view: an automatic configuration holds the token the metadata server
/// or gcloud returned at the moment the client was created, and the client keeps using that copy
/// for as long as it exists. The explicit and emulator cases hold what the caller passed.
public struct ResolvedGCPConfiguration: Sendable {
    public let projectId: String

    /// The value sent in the `Authorization: Bearer` header, `"owner"` in the emulator case.
    public let token: String

    /// The Firestore database to address. Cloud Storage clients ignore it.
    public let databaseId: String

    /// True when the token is the emulator's placeholder rather than a real credential, which is
    /// what makes a client build an http emulator base URL instead of the production one.
    public let isEmulator: Bool

    public init(
        projectId: String,
        token: String,
        databaseId: String = "(default)",
        isEmulator: Bool = false
    ) {
        self.projectId = projectId
        self.token = token
        self.databaseId = databaseId
        self.isEmulator = isEmulator
    }
}
