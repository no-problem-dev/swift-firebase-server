import Foundation

/// 検証済み Firebase ID トークン
///
/// ID トークンの検証が成功した後に返される、安全に使用できるトークン情報。
/// サーバーサイドでユーザーを識別するために使用。
public struct VerifiedToken: Sendable {
    /// Firebase UID
    ///
    /// ユーザーを一意に識別する ID。データベースでのユーザー関連付けに使用。
    public let uid: String

    /// メールアドレス（オプション）
    public let email: String?

    /// メールアドレスが確認済みかどうか
    public let emailVerified: Bool

    /// ユーザー名（オプション）
    public let name: String?

    /// プロフィール画像URL（オプション）
    public let picture: String?

    /// 電話番号（オプション）
    public let phoneNumber: String?

    /// 認証時刻
    ///
    /// ユーザーが Firebase に認証した時刻
    public let authTime: Date

    /// トークン発行時刻
    public let issuedAt: Date

    /// トークン有効期限
    public let expiresAt: Date

    /// サインインプロバイダー
    ///
    /// 例: "password", "google.com", "apple.com"
    public let signInProvider: String?

    /// カスタムクレーム（生データ）
    ///
    /// Firebase の Firebase Claims に含まれる追加情報
    public let firebaseClaims: FirebaseClaim?

    // MARK: - Initializers

    /// JWT ペイロードから初期化
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

    /// 明示的な値で初期化（主にテスト用）
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
