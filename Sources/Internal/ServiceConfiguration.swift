import Foundation

/// The settings every Firebase service client needs, whatever service it talks to.
public protocol ServiceConfiguration: Sendable {
    var projectId: String { get }

    /// The root every request URL is built from.
    ///
    /// Production configurations point at the service's https endpoint; emulator ones point at
    /// plain http on the emulator's host and port.
    var baseURL: URL { get }

    /// The timeout applied to each HTTP request, in seconds, not to a whole operation.
    var timeout: TimeInterval { get }
}

/// A configuration type that can also be pointed at the Firebase Emulator Suite.
///
/// Gives callers one way to build an emulator configuration for any service. A conforming type
/// fills in whatever else it needs from these four values; Cloud Storage, for instance, derives
/// its bucket name from the project ID.
public protocol EmulatorConfigurable {
    /// Creates a configuration aimed at a locally running emulator.
    /// - Parameters:
    ///   - projectId: The project ID the emulator scopes data under. It does not have to exist
    ///     in Google Cloud.
    ///   - host: The host the emulator listens on.
    ///   - port: The port the emulator listens on.
    ///   - timeout: The per-request timeout, in seconds.
    static func emulator(
        projectId: String,
        host: String,
        port: Int,
        timeout: TimeInterval
    ) -> Self
}

/// The host and port of a running emulator, and the default values for both.
public struct EmulatorConfig: Sendable {
    public let host: String

    public let port: Int

    /// The port the Firestore emulator listens on unless `firebase.json` moves it.
    public static let defaultFirestorePort = 8080

    /// The port the Cloud Storage emulator listens on unless `firebase.json` moves it.
    public static let defaultStoragePort = 9199

    /// The host the emulator suite binds to unless `firebase.json` moves it.
    public static let defaultHost = "localhost"

    public init(host: String = Self.defaultHost, port: Int) {
        self.host = host
        self.port = port
    }

    /// Builds the base URL for a service running on this host and port.
    ///
    /// Always plain http, since the emulator does not serve TLS. Traps if the host, port and
    /// path do not form a valid URL.
    /// - Parameter path: The path appended after the host and port, such as `"/v1"`.
    public func buildURL(path: String = "") -> URL {
        URL(string: "http://\(host):\(port)\(path)")!
    }
}
