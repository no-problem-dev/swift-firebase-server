import Foundation

/// The identity carried by a Firebase ID token that has passed verification.
///
/// Getting one back from ``AuthClient/verifyIDToken(_:)`` is what makes ``uid`` safe to trust as the
/// caller's identity. Every other field is copied straight from the token's claims, so treat them as
/// what the user's identity provider said, not as facts your system has confirmed.
public struct VerifiedToken: Sendable {
    /// The Firebase UID.
    ///
    /// This is the identifier to key your own records on: it is stable for the life of the account
    /// and never reused, unlike an email address or a phone number.
    public let uid: String

    public let email: String?

    /// Whether the identity provider says the email address is verified.
    ///
    /// A token with no `email_verified` claim lands here as `false`, so `false` means "not asserted"
    /// rather than "checked and found unverified".
    public let emailVerified: Bool

    public let name: String?

    public let picture: String?

    public let phoneNumber: String?

    /// When the user actually authenticated, which can be far earlier than ``issuedAt`` because ID
    /// tokens are refreshed roughly hourly without the user signing in again.
    public let authTime: Date

    public let issuedAt: Date

    public let expiresAt: Date

    /// How the user signed in, such as `password`, `google.com`, or `apple.com`.
    public let signInProvider: String?

    /// The rest of the `firebase` claim, including the linked identities and the tenant.
    ///
    /// Custom claims set through the Admin SDK are not here: they ride at the top level of the token
    /// and this package does not decode them.
    public let firebaseClaims: FirebaseClaim?

    // MARK: - Initializers

    internal init(payload: JWTPayload) {
        self.uid = payload.uid
        self.email = payload.email
        self.emailVerified = payload.email_verified ?? false
        self.name = payload.name
        self.picture = payload.picture
        self.phoneNumber = payload.phone_number
        self.authTime = payload.authTime
        self.issuedAt = payload.issuedAt
        self.expiresAt = payload.expiresAt
        self.signInProvider = payload.firebase?.sign_in_provider
        self.firebaseClaims = payload.firebase
    }

    /// Creates a token from explicit values, without any token to verify. Intended for tests and fixtures.
    public init(
        uid: String,
        email: String? = nil,
        emailVerified: Bool = false,
        name: String? = nil,
        picture: String? = nil,
        phoneNumber: String? = nil,
        authTime: Date,
        issuedAt: Date,
        expiresAt: Date,
        signInProvider: String? = nil,
        firebaseClaims: FirebaseClaim? = nil
    ) {
        self.uid = uid
        self.email = email
        self.emailVerified = emailVerified
        self.name = name
        self.picture = picture
        self.phoneNumber = phoneNumber
        self.authTime = authTime
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.signInProvider = signInProvider
        self.firebaseClaims = firebaseClaims
    }
}

// MARK: - Equatable

extension VerifiedToken: Equatable {
    /// Compares every stored property except ``firebaseClaims``, so two tokens that differ only in
    /// their linked identities or tenant compare as equal.
    public static func == (lhs: VerifiedToken, rhs: VerifiedToken) -> Bool {
        lhs.uid == rhs.uid &&
        lhs.email == rhs.email &&
        lhs.emailVerified == rhs.emailVerified &&
        lhs.name == rhs.name &&
        lhs.picture == rhs.picture &&
        lhs.phoneNumber == rhs.phoneNumber &&
        lhs.authTime == rhs.authTime &&
        lhs.issuedAt == rhs.issuedAt &&
        lhs.expiresAt == rhs.expiresAt &&
        lhs.signInProvider == rhs.signInProvider
    }
}

// MARK: - CustomStringConvertible

extension VerifiedToken: CustomStringConvertible {
    public var description: String {
        "VerifiedToken(uid: \(uid), email: \(email ?? "nil"), provider: \(signInProvider ?? "nil"))"
    }
}
