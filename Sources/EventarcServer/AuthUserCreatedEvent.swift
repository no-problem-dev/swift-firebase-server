import Foundation

/// The JSON payload of a Firebase Auth user-creation event.
///
/// Eventarc trigger: `google.firebase.auth.user.v1.created`.
///
/// Describes the account that was just created. Only `uid` is guaranteed; every other field is
/// absent for sign-in methods that do not supply it.
///
/// - Note: Firebase Auth is not a direct Eventarc provider. Sign-ups routed through Cloud Audit
///   Logs arrive as `CloudAuditLogEvent` instead, and the memberwise initializer exists so you
///   can build this shape from one.
///
/// ## Example
/// ```swift
/// server.webhook("webhooks", "auth", "user-created", body: AuthUserCreatedEvent.self) { request in
///     let event = request.body
///     print("New user: \(event.uid)")
///     return .ok
/// }
/// ```
public struct AuthUserCreatedEvent: Codable, Sendable {
    /// The Firebase Authentication user ID, which Identity Platform payloads call `localId`.
    public let uid: String

    /// The account's email address, or `nil` for sign-in methods that carry none, such as
    /// anonymous or phone sign-in.
    public let email: String?

    /// Whether the email address has been verified.
    ///
    /// `nil` means the payload omitted the flag, which is not the same as `false`.
    public let emailVerified: Bool?

    public let displayName: String?

    public let photoURL: String?

    /// The account's phone number in E.164 format, present only when a phone credential is
    /// linked.
    public let phoneNumber: String?

    /// Whether the account is disabled and therefore blocked from signing in.
    public let disabled: Bool?

    public let metadata: Metadata?

    /// One entry per identity provider linked to the account, or `nil` when the payload omits
    /// the list. Read the provider IDs here to tell a federated sign-in from an
    /// email-and-password one.
    public let providerData: [ProviderInfo]?

    /// Account timestamps reported by Firebase Auth.
    ///
    /// Both are kept as the strings the service sent; nothing here parses them into `Date`.
    public struct Metadata: Codable, Sendable {
        public let createdAt: String?

        /// When the account most recently signed in, which equals `createdAt` right after a
        /// sign-up.
        public let lastSignedInAt: String?

        private enum CodingKeys: String, CodingKey {
            case createdAt = "createdAt"
            case lastSignedInAt = "lastSignedInAt"
        }
    }

    /// One identity provider's view of the account.
    ///
    /// The values here come from the provider, so they can differ from the top-level ones: a
    /// user can carry a different display name or photo at Google than the one Firebase Auth
    /// shows.
    public struct ProviderInfo: Codable, Sendable {
        /// The provider's identifier, such as `google.com`, `apple.com`, or `password`.
        public let providerId: String?

        /// The user's ID at that provider, which is unrelated to the Firebase `uid`.
        public let uid: String?

        public let email: String?

        public let displayName: String?

        public let photoURL: String?
    }

    private enum CodingKeys: String, CodingKey {
        case uid
        case email
        case emailVerified
        case displayName
        case photoURL
        case phoneNumber
        case disabled
        case metadata
        case providerData
    }

    /// Creates the payload in code rather than decoding it from a request body.
    ///
    /// Use it when a sign-up arrives as a `CloudAuditLogEvent` and you want to hand your own
    /// code the same shape a native Firebase Auth event would have had.
    public init(
        uid: String,
        email: String? = nil,
        emailVerified: Bool? = nil,
        displayName: String? = nil,
        photoURL: String? = nil,
        phoneNumber: String? = nil,
        disabled: Bool? = nil,
        metadata: Metadata? = nil,
        providerData: [ProviderInfo]? = nil
    ) {
        self.uid = uid
        self.email = email
        self.emailVerified = emailVerified
        self.displayName = displayName
        self.photoURL = photoURL
        self.phoneNumber = phoneNumber
        self.disabled = disabled
        self.metadata = metadata
        self.providerData = providerData
    }
}
