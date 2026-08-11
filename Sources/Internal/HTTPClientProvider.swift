import AsyncHTTPClient
import Foundation
import NIOCore

/// Holds the `HTTPClient` a Firebase service client sends its requests through.
///
/// Pass an existing client when the host application already runs one, so its event loops and
/// connection pool are reused; use the no-argument initializer to get a client of your own.
/// Only a client this provider created is ever shut down.
public final class HTTPClientProvider: Sendable {
    private let httpClient: HTTPClient

    /// True when this provider created the client, which is the only case where `deinit` shuts
    /// it down.
    private let ownsClient: Bool

    /// Creates a client on NIO's singleton event loop group.
    ///
    /// The client is shut down synchronously in `deinit`, which blocks the thread that releases
    /// the last reference to this provider.
    public init() {
        self.httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        self.ownsClient = true
    }

    /// Wraps a client the caller already owns.
    ///
    /// Nothing is shut down when this provider is deallocated; the caller keeps responsibility
    /// for the client's lifecycle.
    /// - Parameter client: An HTTP client that is already running.
    public init(client: HTTPClient) {
        self.httpClient = client
        self.ownsClient = false
    }

    deinit {
        if ownsClient {
            try? httpClient.syncShutdown()
        }
    }

    /// The client to send requests on. Do not shut it down here; the provider does that when it
    /// owns it.
    public var client: HTTPClient {
        httpClient
    }
}
