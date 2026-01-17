import Foundation

/// Firebase Auth 認証エラー
///
/// Go バックエンドのエラーコードと対応:
/// - `AUTH_TOKEN_MISSING` → `.tokenMissing`
/// - `AUTH_TOKEN_INVALID` → `.tokenInvalid`
/// - `AUTH_TOKEN_EXPIRED` → `.tokenExpired`
/// - `AUTH_VERIFICATION_FAILED` → `.verificationFailed`
/// - `AUTH_USER_NOT_FOUND` → `.userNotFound`
public enum AuthError: Error, Sendable {
    // MARK: - Token Extraction Errors

    /// Authorization ヘッダーが存在しない
    case tokenMissing

    /// トークン形式が不正（Bearer 形式でない等）
    case tokenInvalid(reason: String)

    /// トークンの有効期限切れ
    case tokenExpired(expiredAt: Date)

    // MARK: - Token Verification Errors

    /// トークン検証失敗
    case verificationFailed(reason: String)

    /// サポートされていないアルゴリズム
    case unsupportedAlgorithm(String)

    /// 署名が不正
    case signatureInvalid

    /// 発行者（issuer）が不正
    case invalidIssuer(expected: String, actual: String)

    /// 対象者（audience）が不正
    case invalidAudience(expected: String, actual: String)

    // MARK: - Public Key Errors

    /// 公開鍵の取得に失敗
    case publicKeyFetchFailed(underlying: Error)

    /// 指定された kid の公開鍵が見つからない
    case publicKeyNotFound(kid: String)

    /// 公開鍵の形式が不正
    case invalidPublicKey(reason: String)

    // MARK: - User Errors

    /// ユーザーが見つからない（sub クレームが空）
    case userNotFound

    // MARK: - Admin API Errors

    /// ユーザー削除に失敗
    case deleteUserFailed(reason: String)

    /// Admin API リクエストに失敗
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

        case .verificationFailed(let reason):
            return "Token verification failed: \(reason)"

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
    /// Go バックエンドとの互換性のためのエラーコード
    public var errorCode: String {
        switch self {
        case .tokenMissing:
            return "AUTH_TOKEN_MISSING"
        case .tokenInvalid:
            return "AUTH_TOKEN_INVALID"
        case .tokenExpired:
            return "AUTH_TOKEN_EXPIRED"
        case .verificationFailed, .unsupportedAlgorithm, .signatureInvalid,
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
