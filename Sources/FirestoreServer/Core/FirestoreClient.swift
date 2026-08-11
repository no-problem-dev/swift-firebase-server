import AsyncHTTPClient
import Foundation
import Internal

/// A client for the Cloud Firestore REST API.
///
/// Calls the REST API directly rather than going through the Firebase SDK, so it runs anywhere
/// server-side Swift does. Every operation is one standalone HTTP request: there is no
/// transaction and no batched commit, so writes to several documents do not land atomically and
/// a read is never part of a later write.
///
/// ## Creating a client
///
/// ### Automatic (Cloud Run / local gcloud)
/// ```swift
/// let firestore = try await FirestoreClient(.auto)
/// ```
///
/// ### Emulator
/// ```swift
/// let firestore = FirestoreClient(.emulator(projectId: "demo-project"))
/// ```
///
/// ### Explicit (tests or a custom auth flow)
/// ```swift
/// let firestore = FirestoreClient(.explicit(projectId: "my-project", token: accessToken))
/// ```
public final class FirestoreClient: Sendable {
    public let configuration: FirestoreConfiguration

    /// The bearer token sent in the `Authorization` header of every request.
    ///
    /// In emulator mode this is the dummy value `owner`, which the emulator accepts unchecked.
    /// The value is captured once at initialization and never refreshed, so a long-lived client
    /// built from a short-lived access token will start failing with HTTP 401 once it expires.
    public let token: String

    public var database: DatabasePath {
        configuration.database
    }

    private let httpClientProvider: HTTPClientProvider

    // MARK: - Initialization

    /// Creates a client, resolving the project ID and access token from the environment.
    ///
    /// On Cloud Run the credentials come from the metadata server; elsewhere they come from the
    /// gcloud CLI. Passing `.emulator` here is also valid: it points the client at the emulator
    /// host over plain HTTP and uses the dummy token instead of contacting either source.
    ///
    /// - Parameters:
    ///   - config: How to obtain the project ID and token.
    ///   - keyEncodingStrategy: How Swift property names map to Firestore field names on write.
    ///   - keyDecodingStrategy: How Firestore field names map back to Swift property names on read.
    /// - Throws: `GCPAuthError` if the project ID or token cannot be resolved.
    public init(
        _ config: GCPConfiguration,
        keyEncodingStrategy: KeyEncodingStrategy = .useDefaultKeys,
        keyDecodingStrategy: KeyDecodingStrategy = .useDefaultKeys
    ) async throws {
        let resolved = try await GCPEnvironment.shared.resolve(config)

        if resolved.isEmulator {
            self.configuration = FirestoreConfiguration.emulator(
                projectId: resolved.projectId,
                databaseId: resolved.databaseId,
                keyEncodingStrategy: keyEncodingStrategy,
                keyDecodingStrategy: keyDecodingStrategy
            )
        } else {
            self.configuration = FirestoreConfiguration(
                projectId: resolved.projectId,
                databaseId: resolved.databaseId,
                keyEncodingStrategy: keyEncodingStrategy,
                keyDecodingStrategy: keyDecodingStrategy
            )
        }
        self.token = resolved.token
        self.httpClientProvider = HTTPClientProvider()
    }

    /// Creates a client without contacting the environment for credentials.
    ///
    /// Use it when the token is already in hand. `.emulator` targets `localhost:8080` and sends
    /// the dummy token `owner`.
    ///
    /// - Parameter config: Must be `.emulator(projectId:)` or `.explicit(projectId:token:)`.
    ///   `.auto` and `.autoWithDatabase` trap, because resolving them requires the async
    ///   initializer.
    public init(_ config: GCPConfiguration) {
        switch config {
        case .auto, .autoWithDatabase:
            fatalError("Use async init for .auto: try await FirestoreClient(.auto)")
        case .emulator(let projectId):
            self.configuration = FirestoreConfiguration.emulator(projectId: projectId)
            self.token = "owner"
        case .explicit(let projectId, let token):
            self.configuration = FirestoreConfiguration(projectId: projectId)
            self.token = token
        }
        self.httpClientProvider = HTTPClientProvider()
    }

    /// Creates a client with explicit key strategies and emulator endpoint.
    ///
    /// - Parameters:
    ///   - config: Must be `.emulator(projectId:)` or `.explicit(projectId:token:)`. `.auto` and
    ///     `.autoWithDatabase` trap, because resolving them requires the async initializer.
    ///   - keyEncodingStrategy: How Swift property names map to Firestore field names on write.
    ///   - keyDecodingStrategy: How Firestore field names map back to Swift property names on read.
    ///   - emulatorHost: The emulator host, used only when `config` is `.emulator`.
    ///   - emulatorPort: The emulator port, used only when `config` is `.emulator`.
    public init(
        _ config: GCPConfiguration,
        keyEncodingStrategy: KeyEncodingStrategy = .useDefaultKeys,
        keyDecodingStrategy: KeyDecodingStrategy = .useDefaultKeys,
        emulatorHost: String = "localhost",
        emulatorPort: Int = 8080
    ) {
        switch config {
        case .auto, .autoWithDatabase:
            fatalError("Use async init for .auto: try await FirestoreClient(.auto)")
        case .emulator(let projectId):
            self.configuration = FirestoreConfiguration.emulator(
                projectId: projectId,
                host: emulatorHost,
                port: emulatorPort,
                keyEncodingStrategy: keyEncodingStrategy,
                keyDecodingStrategy: keyDecodingStrategy
            )
            self.token = "owner"
        case .explicit(let projectId, let token):
            self.configuration = FirestoreConfiguration(
                projectId: projectId,
                keyEncodingStrategy: keyEncodingStrategy,
                keyDecodingStrategy: keyDecodingStrategy
            )
            self.token = token
        }
        self.httpClientProvider = HTTPClientProvider()
    }

    // MARK: - Reference Creation

    /// Returns a reference to a top-level collection.
    ///
    /// - Parameter collectionId: A single path segment. A value that parses to an even number of
    ///   segments — anything containing a `/`, such as `users/abc` — traps, since that names a
    ///   document rather than a collection.
    public func collection(_ collectionId: String) -> CollectionReference {
        let path = try! CollectionPath(collectionId)
        return CollectionReference(database: configuration.database, path: path)
    }

    /// Returns a reference to the document at a slash-separated path.
    ///
    /// - Parameter path: A path with an even number of segments, such as `users/abc` or
    ///   `users/abc/books/xyz`.
    /// - Throws: `PathError.emptyPath` if the path has no segments, or
    ///   `PathError.invalidDocumentPath` if it has an odd number of them.
    public func document(_ path: String) throws -> DocumentReference {
        let docPath = try DocumentPath(path)
        return DocumentReference(database: configuration.database, path: docPath)
    }

    // MARK: - Internal

    internal var client: HTTPClient {
        httpClientProvider.client
    }
}
