import Foundation

/// Firebase Auth ユーザー作成イベントペイロード
///
/// Eventarc トリガー: `google.firebase.auth.user.v1.created`
///
/// Firebase Auth で新規ユーザーが作成された際に送信されるイベントです。
/// ユーザー情報（UID、メール、表示名など）が含まれます。
///
/// ## 使用例
/// ```swift
/// server.webhook("webhooks", "auth", "user-created", body: AuthUserCreatedEvent.self) { request in
///     let event = request.body
///     print("New user: \(event.uid)")
///     return .ok
/// }
/// ```
public struct AuthUserCreatedEvent: Codable, Sendable {
    /// Firebase ユーザーID
    public let uid: String

    /// メールアドレス
    public let email: String?

    /// メール確認済みフラグ
    public let emailVerified: Bool?

    /// 表示名
    public let displayName: String?

    /// プロフィール写真URL
    public let photoURL: String?

    /// 電話番号
    public let phoneNumber: String?

    /// アカウント無効化フラグ
    public let disabled: Bool?

    /// メタデータ
    public let metadata: Metadata?

    /// プロバイダー情報
    public let providerData: [ProviderInfo]?

    /// メタデータ
    public struct Metadata: Codable, Sendable {
        /// 作成日時
        public let createdAt: String?

        /// 最終ログイン日時
        public let lastSignedInAt: String?

        private enum CodingKeys: String, CodingKey {
            case createdAt = "createdAt"
            case lastSignedInAt = "lastSignedInAt"
        }
    }

    /// プロバイダー情報
    public struct ProviderInfo: Codable, Sendable {
        /// プロバイダーID（例: "google.com", "apple.com"）
        public let providerId: String?

        /// プロバイダー固有のUID
        public let uid: String?

        /// メールアドレス
        public let email: String?

        /// 表示名
        public let displayName: String?

        /// プロフィール写真URL
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

    /// 初期化
    ///
    /// Cloud Audit Logsからの変換など、プログラムでインスタンスを作成する場合に使用します。
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
