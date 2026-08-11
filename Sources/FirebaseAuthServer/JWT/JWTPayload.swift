import Foundation

/// The claims carried by a Firebase Authentication ID token.
///
/// The claim set follows the [Firebase documentation](https://firebase.google.com/docs/auth/admin/verify-id-tokens).
/// The six required claims are non-optional here, so a token missing any of them fails to decode
/// rather than failing verification. Claims that are not listed below — including custom claims set
/// through the Admin SDK — are dropped during decoding.
struct JWTPayload: Codable, Sendable {
    // MARK: - Required Claims

    /// Expiry, as a UNIX timestamp.
    ///
    /// Verification rejects the token once this has passed, allowing for the verifier's clock skew.
    let exp: Int

    /// Issue time, as a UNIX timestamp.
    ///
    /// Verification rejects a token issued in the future, allowing for the verifier's clock skew.
    let iat: Int

    /// The audience, which must equal the Firebase project ID.
    let aud: String

    /// The issuer, which must equal `https://securetoken.google.com/{projectId}`.
    let iss: String

    /// The subject: the Firebase UID. Verification requires it to be non-empty.
    let sub: String

    /// When the user actually authenticated, as a UNIX timestamp.
    ///
    /// Verification rejects an authentication time in the future, allowing for clock skew, but never
    /// checks how long ago it was — this is the claim to read yourself if an operation needs a recent
    /// sign-in.
    let auth_time: Int

    // MARK: - Optional Claims

    let email: String?

    let email_verified: Bool?

    let name: String?

    let picture: String?

    let phone_number: String?

    /// The `firebase` claim, holding the sign-in provider and linked identities.
    let firebase: FirebaseClaim?

    // MARK: - Computed Properties

    var expiresAt: Date {
        Date(timeIntervalSince1970: TimeInterval(exp))
    }

    var issuedAt: Date {
        Date(timeIntervalSince1970: TimeInterval(iat))
    }

    var authTime: Date {
        Date(timeIntervalSince1970: TimeInterval(auth_time))
    }

    /// The Firebase UID, an alias for the `sub` claim.
    var uid: String {
        sub
    }
}

// MARK: - Firebase Claim

/// The contents of the `firebase` claim that Firebase Authentication adds to every ID token.
public struct FirebaseClaim: Codable, Sendable {
    /// How the user signed in, such as `password`, `google.com`, or `apple.com`.
    public let sign_in_provider: String?

    /// The second factor used at sign-in, present only when multi-factor authentication was required.
    public let sign_in_second_factor: String?

    public let second_factor_identifier: String?

    /// The tenant this user belongs to, in an Identity Platform multi-tenant project.
    ///
    /// Verification does not check it, so a single-tenant server that starts using tenants has to
    /// compare this itself.
    public let tenant: String?

    /// The identifiers each provider knows this user by, such as
    /// `["google.com": ["1234…"], "email": ["user@example.com"]]`.
    public let identities: [String: [String]]?
}
