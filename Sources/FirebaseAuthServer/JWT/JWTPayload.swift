import Foundation

/// Firebase ID トークンの JWT ペイロード
///
/// Firebase Authentication が発行する ID トークンに含まれるクレーム。
/// [Firebase ドキュメント](https://firebase.google.com/docs/auth/admin/verify-id-tokens) に基づく。
public struct JWTPayload: Codable, Sendable {
    // MARK: - Required Claims

    /// トークンの有効期限（UNIX タイムスタンプ）
    ///
    /// この時刻が現在時刻より未来であることを検証
    public let exp: Int

    /// トークンの発行時刻（UNIX タイムスタンプ）
    ///
    /// この時刻が現在時刻より過去であることを検証
    public let iat: Int

    /// 対象者（Audience）
    ///
    /// Firebase プロジェクトID と一致することを検証
    public let aud: String

    /// 発行者（Issuer）
    ///
    /// `https://securetoken.google.com/{projectId}` と一致することを検証
    public let iss: String

    /// 主体（Subject）= Firebase UID
    ///
    /// 非空文字列であることを検証
    public let sub: String

    /// 認証時刻（UNIX タイムスタンプ）
    ///
    /// この時刻が現在時刻より過去であることを検証
    public let auth_time: Int

    // MARK: - Optional Claims

    /// メールアドレス
    public let email: String?

    /// メールアドレス確認済みフラグ
    public let email_verified: Bool?

    /// ユーザー名
    public let name: String?

    /// プロフィール画像URL
    public let picture: String?

    /// 電話番号
    public let phone_number: String?

    /// Firebase 認証情報
    public let firebase: FirebaseClaim?

    // MARK: - Computed Properties

    /// 有効期限（Date 型）
    public var expiresAt: Date {
        Date(timeIntervalSince1970: TimeInterval(exp))
    }

    /// 発行時刻（Date 型）
    public var issuedAt: Date {
        Date(timeIntervalSince1970: TimeInterval(iat))
    }

    /// 認証時刻（Date 型）
    public var authTime: Date {
        Date(timeIntervalSince1970: TimeInterval(auth_time))
    }

    /// Firebase UID（sub クレームのエイリアス）
    public var uid: String {
        sub
    }
}

// MARK: - Firebase Claim

/// Firebase 固有のクレーム情報
public struct FirebaseClaim: Codable, Sendable {
    /// サインインプロバイダー
    ///
    /// 例: "password", "google.com", "apple.com"
    public let sign_in_provider: String?

    /// サインイン時のセカンドファクター
    public let sign_in_second_factor: String?

    /// セカンドファクター識別子
    public let second_factor_identifier: String?

    /// テナントID（マルチテナント環境用）
    public let tenant: String?

    /// 認証プロバイダーの識別子情報
    public let identities: [String: [String]]?
}
