import Foundation

/// Everything that can go wrong while verifying a Firebase ID token or calling the Admin API.
///
/// The cases map onto the error codes of the Go backend through ``errorCode``:
/// - `AUTH_TOKEN_MISSING` → `.tokenMissing`
/// - `AUTH_TOKEN_INVALID` → `.tokenInvalid`
/// - `AUTH_TOKEN_EXPIRED` → `.tokenExpired`
/// - `AUTH_VERIFICATION_FAILED` → `.signatureInvalid` and the other verification cases
/// - `AUTH_USER_NOT_FOUND` → `.userNotFound`
public enum AuthError: Error, Sendable {
    // MARK: - Token Extraction Errors

    /// The `Authorization` header value was empty.
    case tokenMissing

    /// The token could not be read far enough to judge it.
    ///
    /// Covers a header that is not `Bearer <token>`, a JWT without three parts, unreadable Base64URL
    /// or JSON, a missing `kid`, and an `iat` or `auth_time` set in the future.
    case tokenInvalid(reason: String)

    /// The `exp` claim is further in the past than the verifier's clock skew allowance.
    case tokenExpired(expiredAt: Date)

    // MARK: - Token Verification Errors

    /// The header's `alg` was something other than `RS256`.
    case unsupportedAlgorithm(String)

    /// The RS256 signature did not match Google's certificate for the token's `kid`.
    case signatureInvalid

    /// The `iss` claim is not `https://securetoken.google.com/{projectId}` for the configured project.
    case invalidIssuer(expected: String, actual: String)

    /// The `aud` claim is not the configured project ID, so the token was minted for another project.
    case invalidAudience(expected: String, actual: String)

    // MARK: - Public Key Errors

    /// Google's key set could not be fetched.
    ///
    /// The wrapped error is the transport failure, or an `NSError` carrying a non-`200` status code,
    /// or the decoding failure from an unexpected body.
    case publicKeyFetchFailed(underlying: Error)

    /// Google's key set has no certificate under this key ID, even after a refresh.
    ///
    /// Usually the token was signed by something other than Firebase, or by a key that has since been
    /// rotated out.
    case publicKeyNotFound(kid: String)

    /// The certificate came back in a shape that could not be parsed down to an RSA public key.
    case invalidPublicKey(reason: String)

    // MARK: - User Errors

    /// The token's `sub` claim is empty.
    ///
    /// It is a malformed token, not the result of looking a user up and finding nobody.
    case userNotFound

    // MARK: - Admin API Errors

    /// A delete request could not be sent or the reply was not an HTTP response.
    ///
    /// A deletion the API itself refuses arrives as ``adminAPIFailed(statusCode:message:)``.
    case deleteUserFailed(reason: String)

    /// The Identity Toolkit API answered with a non-`200` status, and the message it gave.
    case adminAPIFailed(statusCode: Int, message: String)
}

// MARK: - CustomStringConvertible

extension AuthError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .tokenMissing:
            return "Authorization header is missing"

        case .tokenInvalid(let reason):
            return "Token is invalid: \(reason)"

        case .tokenExpired(let expiredAt):
            let formatter = ISO8601DateFormatter()
            return "Token expired at \(formatter.string(from: expiredAt))"

        case .unsupportedAlgorithm(let alg):
            return "Unsupported algorithm: \(alg). Expected RS256"

        case .signatureInvalid:
            return "Token signature is invalid"

        case .invalidIssuer(let expected, let actual):
            return "Invalid issuer. Expected: \(expected), got: \(actual)"

        case .invalidAudience(let expected, let actual):
            return "Invalid audience. Expected: \(expected), got: \(actual)"

        case .publicKeyFetchFailed(let underlying):
            return "Failed to fetch public keys: \(underlying.localizedDescription)"

        case .publicKeyNotFound(let kid):
            return "Public key not found for kid: \(kid)"

        case .invalidPublicKey(let reason):
            return "Invalid public key: \(reason)"

        case .userNotFound:
            return "User ID (sub claim) is empty or missing"

        case .deleteUserFailed(let reason):
            return "Failed to delete user: \(reason)"

        case .adminAPIFailed(let statusCode, let message):
            return "Admin API request failed (status: \(statusCode)): \(message)"
        }
    }
}

// MARK: - Error Code (Go Backend Compatibility)

extension AuthError {
    /// The error code string that matches the Go backend's vocabulary.
    ///
    /// Several cases collapse into one code: every signature, key, issuer, and audience failure
    /// reports `AUTH_VERIFICATION_FAILED`, and both Admin API cases report `AUTH_ADMIN_API_ERROR`.
    /// Send this to clients and keep ``description`` for your own logs.
    public var errorCode: String {
        switch self {
        case .tokenMissing:
            return "AUTH_TOKEN_MISSING"
        case .tokenInvalid:
            return "AUTH_TOKEN_INVALID"
        case .tokenExpired:
            return "AUTH_TOKEN_EXPIRED"
        case .unsupportedAlgorithm, .signatureInvalid,
             .invalidIssuer, .invalidAudience, .publicKeyFetchFailed,
             .publicKeyNotFound, .invalidPublicKey:
            return "AUTH_VERIFICATION_FAILED"
        case .userNotFound:
            return "AUTH_USER_NOT_FOUND"
        case .deleteUserFailed, .adminAPIFailed:
            return "AUTH_ADMIN_API_ERROR"
        }
    }
}
