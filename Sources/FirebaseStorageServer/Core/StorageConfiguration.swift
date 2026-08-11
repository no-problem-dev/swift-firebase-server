import Foundation
import Internal

/// The endpoints, bucket, and timeout a storage client sends its requests with.
public struct StorageConfiguration: ServiceConfiguration, EmulatorConfigurable, Sendable {
    /// The Google Cloud project that owns the bucket.
    ///
    /// Requests address objects by bucket, so this never appears in a request URL. It is carried
    /// for identification and to derive the default emulator bucket name.
    public let projectId: String

    public let bucket: String

    /// The root the metadata, download, and delete endpoints hang off.
    ///
    /// `https://storage.googleapis.com/storage/v1` in production, or the emulator's `/v0` root.
    public let baseURL: URL

    /// The root the upload endpoint hangs off.
    ///
    /// The JSON API serves uploads from a separate host path,
    /// `https://storage.googleapis.com/upload/storage/v1`. Against the emulator it is the same
    /// `/v0` root as ``baseURL``.
    public let uploadBaseURL: URL

    /// The deadline applied to each request, in seconds.
    ///
    /// It covers the whole request, including the body transfer, so it also caps how long a large
    /// upload or download may take. The value is truncated to whole seconds when the request is
    /// built, so anything below one second becomes a zero-second deadline.
    public let timeout: TimeInterval

    /// Whether requests go to the Storage emulator.
    ///
    /// It also switches ``publicURL(for:)`` to an `http://` URL on the emulator host.
    public let useEmulator: Bool

    /// Creates a configuration pointed at production Cloud Storage.
    /// - Parameters:
    ///   - projectId: The Google Cloud project that owns the bucket.
    ///   - bucket: The bucket name, for example `"my-project.appspot.com"`.
    ///   - timeout: The per-request deadline in seconds. Fractional values truncate to whole
    ///     seconds when the request is built.
    public init(
        projectId: String,
        bucket: String,
        timeout: TimeInterval = 60
    ) {
        self.projectId = projectId
        self.bucket = bucket
        self.baseURL = URL(string: "https://storage.googleapis.com/storage/v1")!
        self.uploadBaseURL = URL(string: "https://storage.googleapis.com/upload/storage/v1")!
        self.timeout = timeout
        self.useEmulator = false
        self.emulatorHost = nil
    }

    /// Creates a configuration pointed at the Firebase Storage emulator.
    ///
    /// Both the read and the upload endpoints become the emulator's `/v0` root on the same host,
    /// and no real credentials are involved — the client sends the literal token `"owner"`.
    /// - Parameters:
    ///   - projectId: The project ID the emulator was started with.
    ///   - bucket: The bucket name.
    ///   - host: The host the emulator listens on.
    ///   - port: The port the emulator listens on. 9199 is the Firebase default for Storage.
    ///   - timeout: The per-request deadline in seconds.
    public static func emulator(
        projectId: String,
        bucket: String,
        host: String = EmulatorConfig.defaultHost,
        port: Int = EmulatorConfig.defaultStoragePort,
        timeout: TimeInterval = 60
    ) -> StorageConfiguration {
        let emulator = EmulatorConfig(host: host, port: port)
        return StorageConfiguration(
            projectId: projectId,
            bucket: bucket,
            baseURL: emulator.buildURL(path: "/v0"),
            uploadBaseURL: emulator.buildURL(path: "/v0"),
            timeout: timeout,
            useEmulator: true,
            emulatorHost: "\(host):\(port)"
        )
    }

    /// Creates an emulator configuration, defaulting the bucket to `"{projectId}.appspot.com"`.
    ///
    /// This is the `EmulatorConfigurable` requirement, which has no bucket parameter. Call the
    /// overload that takes `bucket:` when the bucket does not follow that naming.
    public static func emulator(
        projectId: String,
        host: String,
        port: Int,
        timeout: TimeInterval
    ) -> StorageConfiguration {
        // Derive the bucket name from the project ID.
        emulator(
            projectId: projectId,
            bucket: "\(projectId).appspot.com",
            host: host,
            port: port,
            timeout: timeout
        )
    }

    /// The `host:port` the emulator answers on, used only to build public URLs.
    ///
    /// `nil` in production.
    internal let emulatorHost: String?

    private init(
        projectId: String,
        bucket: String,
        baseURL: URL,
        uploadBaseURL: URL,
        timeout: TimeInterval,
        useEmulator: Bool,
        emulatorHost: String?
    ) {
        self.projectId = projectId
        self.bucket = bucket
        self.baseURL = baseURL
        self.uploadBaseURL = uploadBaseURL
        self.timeout = timeout
        self.useEmulator = useEmulator
        self.emulatorHost = emulatorHost
    }

    // MARK: - URL Builders

    /// Percent-encodes an object name for use in a URL.
    ///
    /// Everything outside RFC 3986's unreserved set is escaped, so `/` becomes `%2F` and `&`, `+`,
    /// `#`, `?`, and spaces are escaped too. The JSON API takes the object name as a single path
    /// segment of `b/{bucket}/o/{object}`, so a nested name that keeps its slashes addresses a URL
    /// that does not route; the upload endpoint takes it as the `name` query value, where an
    /// unescaped `&` or `+` changes the name that arrives.
    static func percentEncodedObjectName(_ path: String) -> String {
        let unreserved = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        )
        // Non-ASCII characters are outside the set, so they are escaped as their UTF-8 bytes and
        // the force-unwrap-free fallback never applies.
        return path.addingPercentEncoding(withAllowedCharacters: unreserved) ?? path
    }

    /// The JSON API URL for an object's resource: metadata reads and deletes.
    func objectURL(for path: String) -> String {
        "\(baseURL)/b/\(Self.percentEncodedObjectName(bucket))/o/\(Self.percentEncodedObjectName(path))"
    }

    /// The JSON API URL for an object's bytes.
    func objectMediaURL(for path: String) -> String {
        "\(objectURL(for: path))?alt=media"
    }

    /// The JSON API URL for a single-request media upload, which names the object in the query.
    func uploadURL(for path: String) -> String {
        "\(uploadBaseURL)/b/\(Self.percentEncodedObjectName(bucket))/o?uploadType=media&name=\(Self.percentEncodedObjectName(path))"
    }

    /// Builds the unauthenticated URL for an object.
    ///
    /// Returns `https://storage.googleapis.com/{bucket}/{path}`, or `http://{host}:{port}/{bucket}/{path}`
    /// when configured for the emulator. The URL is unsigned and carries no token, so it never
    /// expires and only resolves for objects the bucket grants public read on. The path is
    /// interpolated as given — no percent-encoding is applied here beyond what `URL` parsing does.
    /// - Parameter path: The object name inside the bucket, for example `"images/photo.jpg"`.
    public func publicURL(for path: String) -> URL {
        if useEmulator, let host = emulatorHost {
            return URL(string: "http://\(host)/\(bucket)/\(path)")!
        }
        return URL(string: "https://storage.googleapis.com/\(bucket)/\(path)")!
    }
}
