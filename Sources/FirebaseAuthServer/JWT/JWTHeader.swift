import Foundation

/// The header of a Firebase ID token.
///
/// Only two fields matter to verification:
/// - `alg`: the signing algorithm. Firebase uses `RS256`; the emulator uses `none`.
/// - `kid`: the key ID that selects one of Google's published certificates. The emulator omits it.
struct JWTHeader: Codable, Sendable {
    /// The signing algorithm.
    ///
    /// A production verification rejects anything other than `RS256`. In emulator mode the field is
    /// never looked at, so the emulator's `none` passes.
    let alg: String

    /// The key ID, which picks one certificate out of Google's key set.
    ///
    /// A production verification fails without it. Emulator tokens leave it out.
    let kid: String?

    /// The `typ` header. It is decoded but never checked, so a token claiming any type is accepted.
    let typ: String?

    init(alg: String, kid: String? = nil, typ: String? = nil) {
        self.alg = alg
        self.kid = kid
        self.typ = typ
    }
}
