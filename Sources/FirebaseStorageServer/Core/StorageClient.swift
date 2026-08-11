import AsyncHTTPClient
import Foundation
import Internal
import NIOCore
import NIOHTTP1

/// A client for the Cloud Storage JSON API, for use from server-side Swift.
///
/// Calls the Cloud Storage JSON API v1 over HTTP rather than linking the Firebase SDK, so it runs
/// wherever `AsyncHTTPClient` runs. Every call buffers whole payloads in memory: an upload sends
/// the `Data` you hand it in a single request, and a download collects at most 100 MB.
///
/// One client addresses one bucket, fixed at initialization. Each request carries a bearer token
/// that is resolved once and never refreshed — see ``token``.
///
/// ## Creating a client
///
/// ### Resolved automatically (Cloud Run metadata server or local gcloud ADC)
/// ```swift
/// let storage = try await StorageClient(.auto, bucket: "my-bucket")
/// ```
///
/// ### Emulator
/// ```swift
/// let storage = StorageClient(.emulator(projectId: "demo-project"), bucket: "my-bucket")
/// ```
///
/// ### Credentials you already hold
/// ```swift
/// let storage = StorageClient(.explicit(projectId: "my-project", token: accessToken), bucket: "my-bucket")
/// ```
public final class StorageClient: Sendable {
    public let configuration: StorageConfiguration

    /// The bearer token sent on every request.
    ///
    /// Resolved once during initialization and never refreshed, so a client held past the token's
    /// lifetime starts failing with `StorageError.unauthenticated`; build a new client instead of
    /// keeping one for the lifetime of the process. Against the emulator this is the literal
    /// string `"owner"`.
    public let token: String

    private let httpClientProvider: HTTPClientProvider

    // MARK: - Initialization

    /// Creates a client, resolving credentials asynchronously.
    ///
    /// Required for `.auto`, which fetches an access token from the Cloud Run metadata server or
    /// from local gcloud application default credentials. `.emulator` and `.explicit` also work
    /// here and resolve without a network round trip.
    /// - Parameters:
    ///   - config: How the project ID and access token are obtained.
    ///   - bucket: The bucket every call on this client addresses.
    /// - Throws: An error from credential resolution if no token can be obtained.
    public init(_ config: GCPConfiguration, bucket: String) async throws {
        let resolved = try await GCPEnvironment.shared.resolve(config)

        if resolved.isEmulator {
            self.configuration = StorageConfiguration.emulator(
                projectId: resolved.projectId,
                bucket: bucket
            )
        } else {
            self.configuration = StorageConfiguration(
                projectId: resolved.projectId,
                bucket: bucket
            )
        }
        self.token = resolved.token
        self.httpClientProvider = HTTPClientProvider()
    }

    /// Creates a client from credentials that need no asynchronous lookup.
    ///
    /// `.emulator` uses the literal token `"owner"`, which the Storage emulator accepts in place
    /// of a real access token.
    /// - Important: `.auto` and `.autoWithDatabase` trap with `fatalError` here; they need the
    ///   asynchronous initializer.
    /// - Parameters:
    ///   - config: Must be `.emulator` or `.explicit`.
    ///   - bucket: The bucket every call on this client addresses.
    public init(_ config: GCPConfiguration, bucket: String) {
        switch config {
        case .auto, .autoWithDatabase:
            fatalError("Use async init for .auto: try await StorageClient(.auto, bucket:)")
        case .emulator(let projectId):
            self.configuration = StorageConfiguration.emulator(projectId: projectId, bucket: bucket)
            self.token = "owner"
        case .explicit(let projectId, let token):
            self.configuration = StorageConfiguration(projectId: projectId, bucket: bucket)
            self.token = token
        }
        self.httpClientProvider = HTTPClientProvider()
    }

    // MARK: - Public API

    /// Uploads data as a simple, single-request upload.
    ///
    /// Sends `POST {upload endpoint}/b/{bucket}/o?uploadType=media&name={path}`. The whole body
    /// travels in one request and is held in memory; there is no multipart or resumable path and
    /// no size threshold that switches to one, so large payloads restart from zero on failure.
    ///
    /// `path` is percent-encoded in full before it goes into the `name` query value, so an object
    /// name holding `/`, `&`, `+`, or a space arrives as the name you passed.
    /// - Parameters:
    ///   - data: The bytes to store as the object's content.
    ///   - path: The object name inside the bucket, for example `"images/user123.jpg"`.
    ///   - contentType: The MIME type recorded with the object, for example `"image/jpeg"`.
    /// - Returns: The object resource the API echoes back, including the assigned generation, size,
    ///   and MD5 hash.
    /// - Throws: `StorageError` mapped from the status code for anything other than 200, or
    ///   `StorageError.invalidArgument` when the response body is not a parseable object resource.
    public func upload(
        data: Data,
        path: String,
        contentType: String
    ) async throws -> StorageObject {
        try Self.validateObjectPath(path)
        let url = configuration.uploadURL(for: path)

        var request = HTTPClientRequest(url: url)
        request.method = .POST
        request.headers.add(name: "Authorization", value: "Bearer \(token)")
        request.headers.add(name: "Content-Type", value: contentType)
        request.headers.add(name: "Content-Length", value: String(data.count))
        request.body = .bytes(ByteBuffer(data: data))

        let response = try await httpClientProvider.client.execute(
            request,
            timeout: .seconds(Int64(configuration.timeout))
        )
        let body = try await response.body.collect(upTo: 10 * 1024 * 1024)

        guard response.status == .ok else {
            throw StorageError.fromHTTPResponse(
                statusCode: Int(response.status.code),
                body: body.toData(),
                path: path
            )
        }

        let bodyData = body.toData()
        guard let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            let bodyString = String(data: bodyData, encoding: .utf8) ?? "Unable to decode body"
            throw StorageError.invalidArgument(message: "Invalid JSON response from server. Body: \(bodyString)")
        }

        guard let storageObject = StorageObject.fromJSON(json) else {
            let jsonString = String(data: bodyData, encoding: .utf8) ?? "Unable to decode JSON"
            throw StorageError.invalidArgument(message: "Failed to parse StorageObject from JSON. JSON: \(jsonString)")
        }

        return storageObject
    }

    /// Downloads an object's bytes in full.
    ///
    /// Sends `GET {base}/b/{bucket}/o/{path}?alt=media` and collects the whole response into
    /// memory. The client is bounded at 100 MB per object — not by any Cloud Storage limit, but by
    /// this buffer — so there is no streaming or ranged read.
    ///
    /// `path` is percent-encoded in full, so a nested name such as `images/a.jpg` addresses the
    /// object resource as the single path segment `images%2Fa.jpg` that the JSON API expects.
    /// - Parameter path: The object name inside the bucket.
    /// - Throws: `StorageError.notFound` when no such object exists (the API answers 404); other
    ///   statuses map by code. A response larger than 100 MB throws the collector's own error
    ///   rather than a `StorageError`.
    public func download(path: String) async throws -> Data {
        try Self.validateObjectPath(path)
        let url = configuration.objectMediaURL(for: path)

        var request = HTTPClientRequest(url: url)
        request.method = .GET
        request.headers.add(name: "Authorization", value: "Bearer \(token)")

        let response = try await httpClientProvider.client.execute(
            request,
            timeout: .seconds(Int64(configuration.timeout))
        )
        let body = try await response.body.collect(upTo: 100 * 1024 * 1024)

        guard response.status == .ok else {
            throw StorageError.fromHTTPResponse(
                statusCode: Int(response.status.code),
                body: body.toData(),
                path: path
            )
        }

        return body.toData()
    }

    /// Deletes the object at the given path.
    ///
    /// Sends `DELETE {base}/b/{bucket}/o/{path}`, accepting both 204 and 200 as success. Deletes
    /// the object's live version only; it does not name a generation.
    /// - Parameter path: The object name inside the bucket.
    /// - Throws: `StorageError.notFound` when no such object exists. Deleting a missing object is
    ///   an error here, not a silent no-op.
    public func delete(path: String) async throws {
        try Self.validateObjectPath(path)
        let url = configuration.objectURL(for: path)

        var request = HTTPClientRequest(url: url)
        request.method = .DELETE
        request.headers.add(name: "Authorization", value: "Bearer \(token)")

        let response = try await httpClientProvider.client.execute(
            request,
            timeout: .seconds(Int64(configuration.timeout))
        )

        guard response.status == .noContent || response.status == .ok else {
            let body = try await response.body.collect(upTo: 1 * 1024 * 1024)
            throw StorageError.fromHTTPResponse(
                statusCode: Int(response.status.code),
                body: body.toData(),
                path: path
            )
        }
    }

    /// Deletes several objects and reports the ones that failed.
    ///
    /// The deletes run one after another, not concurrently, and a failure never stops the run:
    /// every path is attempted. Nothing is rolled back, so a partial delete is a normal outcome —
    /// inspect the result rather than assuming all-or-nothing.
    /// - Parameter paths: The object names to delete.
    /// - Returns: One entry per failed path, in the order the paths were given; empty when every
    ///   delete succeeded. Failures that are not `StorageError` are wrapped as `.unknown` with a
    ///   status code of `-1`.
    public func deleteMultiple(paths: [String]) async -> [(path: String, error: StorageError)] {
        var failures: [(path: String, error: StorageError)] = []

        for path in paths {
            do {
                try await delete(path: path)
            } catch let error as StorageError {
                failures.append((path: path, error: error))
            } catch {
                failures.append((path: path, error: .unknown(statusCode: -1, message: error.localizedDescription)))
            }
        }

        return failures
    }

    /// Fetches an object's metadata without transferring its content.
    ///
    /// Sends `GET {base}/b/{bucket}/o/{path}` with no `alt=media`, so the API returns the object
    /// resource — size, content type, MD5 hash, timestamps — instead of the bytes. Use it as an
    /// existence check when you do not want to pay for the download.
    /// - Parameter path: The object name inside the bucket.
    /// - Throws: `StorageError.notFound` when no such object exists. A body that parses as JSON but
    ///   is not an object resource becomes `.invalidArgument`; a body that is not JSON at all
    ///   propagates the `JSONSerialization` error rather than a `StorageError`.
    public func getMetadata(path: String) async throws -> StorageObject {
        try Self.validateObjectPath(path)
        let url = configuration.objectURL(for: path)

        var request = HTTPClientRequest(url: url)
        request.method = .GET
        request.headers.add(name: "Authorization", value: "Bearer \(token)")

        let response = try await httpClientProvider.client.execute(
            request,
            timeout: .seconds(Int64(configuration.timeout))
        )
        let body = try await response.body.collect(upTo: 1 * 1024 * 1024)

        guard response.status == .ok else {
            throw StorageError.fromHTTPResponse(
                statusCode: Int(response.status.code),
                body: body.toData(),
                path: path
            )
        }

        guard
            let json = try JSONSerialization.jsonObject(with: body.toData()) as? [String: Any],
            let storageObject = StorageObject.fromJSON(json)
        else {
            throw StorageError.invalidArgument(message: "Invalid response from server")
        }

        return storageObject
    }

    /// Builds the unauthenticated URL for an object.
    ///
    /// Returns `https://storage.googleapis.com/{bucket}/{path}`, or the emulator host when the
    /// client is configured for one. This is neither a signed URL nor a Firebase download URL with
    /// an access token: it carries no credentials and therefore never expires, and it only resolves
    /// for objects the bucket grants public read on. For anything else, use ``download(path:)`` or
    /// the object's `mediaLink`, both of which require the `Authorization` header.
    /// - Parameter path: The object name inside the bucket.
    public func publicURL(for path: String) -> URL {
        configuration.publicURL(for: path)
    }

    // MARK: - Path Validation

    /// Rejects object names Cloud Storage does not accept, before a request is built.
    ///
    /// The rules are the ones the service documents: a name may not be empty, may not be `.` or
    /// `..`, and may not contain a carriage return or line feed. Everything else is passed
    /// through — object names are opaque to Cloud Storage, so `a/../b` names a real object.
    /// - Throws: ``StorageError/invalidPath(path:)``.
    static func validateObjectPath(_ path: String) throws {
        guard !path.isEmpty, path != ".", path != ".." else {
            throw StorageError.invalidPath(path: path)
        }
        guard !path.contains(where: { $0 == "\r" || $0 == "\n" }) else {
            throw StorageError.invalidPath(path: path)
        }
    }

    // MARK: - Internal

    internal var client: HTTPClient {
        httpClientProvider.client
    }
}
