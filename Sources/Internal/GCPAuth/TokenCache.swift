import Foundation

/// A fetched access token together with the moment it stops being usable.
struct TokenCache: Sendable {
    let token: String

    /// When the token truly expires, before the refresh margin is taken off.
    let expiresAt: Date

    /// Whether the token is still worth using, counting it as expired five minutes early.
    ///
    /// The margin absorbs clock skew and the time a request spends in flight, so a token handed
    /// out here is good for at least another five minutes.
    var isValid: Bool {
        Date() < expiresAt.addingTimeInterval(-300)
    }

    /// Creates an entry that expires the given number of seconds from now.
    ///
    /// The lifetime is measured from this call rather than from the moment the issuer minted the
    /// token, so any delay in transit is spent out of it.
    ///
    /// - Parameters:
    ///   - token: The token as returned by the metadata server or gcloud.
    ///   - expiresIn: The lifetime the issuer reported, in seconds. A value at or below 300
    ///     produces an entry that is already invalid.
    init(token: String, expiresIn: Int) {
        self.token = token
        self.expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
    }
}
