import Foundation
import Internal

/// Settings that tell an ``AuthClient`` which project a token must belong to.
///
/// The project ID drives both values a token is matched against: the expected audience and the
/// expected issuer. Everything else here is transport detail, plus the emulator switch.
public struct AuthConfiguration: Sendable {
    /// The Google Cloud project ID, which is also the audience every accepted token must carry.
    public let projectId: String

    /// How long to wait for the fetch of Google's public keys, in seconds.
    public let timeout: TimeInterval

    /// Whether token verification is bypassed for the Firebase Auth emulator.
    ///
    /// - Warning: When this is `true` the verifier accepts unsigned tokens and checks nothing but a
    ///   non-empty `sub`: expiry, audience, and issuer are all ignored.
    public let useEmulator: Bool

    /// The emulator host, when ``useEmulator`` is set.
    ///
    /// Verification never contacts the emulator — an emulator token is decoded locally — so this is
    /// carried for callers that need to build their own emulator URLs.
    public let emulatorHost: String?

    /// The emulator port, when ``useEmulator`` is set. Like ``emulatorHost``, it is informational.
    public let emulatorPort: Int?

    /// The port the Firebase Auth emulator listens on by default.
    public static let defaultEmulatorPort = 9099

    /// Google's endpoint for the Firebase ID token signing certificates, keyed by key ID.
    public static let publicKeysURL = URL(
        string: "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com"
    )!

    // MARK: - Initializers

    /// Creates a production configuration, which verifies signatures and claims in full.
    /// - Parameters:
    ///   - projectId: The Google Cloud project ID.
    ///   - timeout: Seconds to allow for the public key fetch. Defaults to 30.
    public init(
        projectId: String,
        timeout: TimeInterval = 30
    ) {
        self.projectId = projectId
        self.timeout = timeout
        self.useEmulator = false
        self.emulatorHost = nil
        self.emulatorPort = nil
    }

    /// Creates a configuration that skips verification, for use against the Firebase Auth emulator.
    ///
    /// - Parameters:
    ///   - projectId: The Google Cloud project ID.
    ///   - host: The emulator host. Defaults to `localhost`.
    ///   - port: The emulator port. Defaults to 9099.
    ///   - timeout: Seconds to allow for a request. Defaults to 30.
    ///
    /// - Warning: A client built from this accepts any well-formed token that carries a `sub`, with no
    ///   signature, expiry, audience, or issuer check. Keep it out of anything a real client can reach.
    public static func emulator(
        projectId: String,
        host: String = EmulatorConfig.defaultHost,
        port: Int = defaultEmulatorPort,
        timeout: TimeInterval = 30
    ) -> AuthConfiguration {
        AuthConfiguration(
            projectId: projectId,
            timeout: timeout,
            useEmulator: true,
            emulatorHost: host,
            emulatorPort: port
        )
    }

    private init(
        projectId: String,
        timeout: TimeInterval,
        useEmulator: Bool,
        emulatorHost: String?,
        emulatorPort: Int?
    ) {
        self.projectId = projectId
        self.timeout = timeout
        self.useEmulator = useEmulator
        self.emulatorHost = emulatorHost
        self.emulatorPort = emulatorPort
    }

    // MARK: - Computed Properties

    /// The issuer a token's `iss` claim must match exactly.
    ///
    /// Firebase issues tokens as `https://securetoken.google.com/{projectId}`.
    public var expectedIssuer: String {
        "https://securetoken.google.com/\(projectId)"
    }

    /// The audience a token's `aud` claim must match exactly, which for Firebase is the project ID.
    public var expectedAudience: String {
        projectId
    }
}
