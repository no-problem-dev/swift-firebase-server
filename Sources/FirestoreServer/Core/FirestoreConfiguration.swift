import Foundation
import Internal

/// Which Firestore database a client talks to, over which endpoint, and how it names fields.
public struct FirestoreConfiguration: ServiceConfiguration, EmulatorConfigurable, Sendable {
    public let database: DatabasePath

    public var projectId: String {
        database.projectId
    }

    /// The API root every request is built on.
    ///
    /// `https://firestore.googleapis.com/v1` in production, or `http://host:port/v1` — plain
    /// HTTP, no TLS — when the configuration was made with `emulator(projectId:)`.
    public let baseURL: URL

    /// Applied to each individual REST request, in seconds.
    public let timeout: TimeInterval

    /// How Swift property names are turned into Firestore field names when writing.
    public let keyEncodingStrategy: KeyEncodingStrategy

    /// How Firestore field names are turned back into Swift property names when reading.
    public let keyDecodingStrategy: KeyDecodingStrategy

    /// Creates a configuration pointing at the production Firestore endpoint.
    /// - Parameters:
    ///   - projectId: The Google Cloud project ID.
    ///   - databaseId: The Firestore database ID; leave it at `"(default)"` unless the project
    ///     uses a named database.
    ///   - timeout: The per-request timeout in seconds.
    ///   - keyEncodingStrategy: How Swift property names are turned into Firestore field names.
    ///   - keyDecodingStrategy: How Firestore field names are turned back into property names.
    public init(
        projectId: String,
        databaseId: String = "(default)",
        timeout: TimeInterval = 30,
        keyEncodingStrategy: KeyEncodingStrategy = .useDefaultKeys,
        keyDecodingStrategy: KeyDecodingStrategy = .useDefaultKeys
    ) {
        self.database = DatabasePath(projectId: projectId, databaseId: databaseId)
        self.baseURL = URL(string: "https://firestore.googleapis.com/v1")!
        self.timeout = timeout
        self.keyEncodingStrategy = keyEncodingStrategy
        self.keyDecodingStrategy = keyDecodingStrategy
    }

    /// Creates a configuration pointing at a local Firebase Emulator instead of Google's servers.
    ///
    /// Only the host changes; the paths and request bodies are the same as production. Security
    /// rules and IAM are not enforced by the emulator, so any bearer token is accepted.
    ///
    /// - Parameters:
    ///   - projectId: The project ID the emulator was started with. Any value works.
    ///   - databaseId: The Firestore database ID.
    ///   - host: The host the emulator listens on.
    ///   - port: The port the emulator listens on.
    ///   - timeout: The per-request timeout in seconds.
    ///   - keyEncodingStrategy: How Swift property names are turned into Firestore field names.
    ///   - keyDecodingStrategy: How Firestore field names are turned back into property names.
    public static func emulator(
        projectId: String,
        databaseId: String = "(default)",
        host: String = EmulatorConfig.defaultHost,
        port: Int = EmulatorConfig.defaultFirestorePort,
        timeout: TimeInterval = 30,
        keyEncodingStrategy: KeyEncodingStrategy = .useDefaultKeys,
        keyDecodingStrategy: KeyDecodingStrategy = .useDefaultKeys
    ) -> FirestoreConfiguration {
        let emulator = EmulatorConfig(host: host, port: port)
        return FirestoreConfiguration(
            database: DatabasePath(projectId: projectId, databaseId: databaseId),
            baseURL: emulator.buildURL(path: "/v1"),
            timeout: timeout,
            keyEncodingStrategy: keyEncodingStrategy,
            keyDecodingStrategy: keyDecodingStrategy
        )
    }

    /// Creates an emulator configuration for the default database with the default key strategies.
    public static func emulator(
        projectId: String,
        host: String,
        port: Int,
        timeout: TimeInterval
    ) -> FirestoreConfiguration {
        emulator(
            projectId: projectId,
            databaseId: "(default)",
            host: host,
            port: port,
            timeout: timeout,
            keyEncodingStrategy: .useDefaultKeys,
            keyDecodingStrategy: .useDefaultKeys
        )
    }

    /// Creates a configuration with an explicit base URL.
    internal init(
        database: DatabasePath,
        baseURL: URL,
        timeout: TimeInterval,
        keyEncodingStrategy: KeyEncodingStrategy = .useDefaultKeys,
        keyDecodingStrategy: KeyDecodingStrategy = .useDefaultKeys
    ) {
        self.database = database
        self.baseURL = baseURL
        self.timeout = timeout
        self.keyEncodingStrategy = keyEncodingStrategy
        self.keyDecodingStrategy = keyDecodingStrategy
    }
}
