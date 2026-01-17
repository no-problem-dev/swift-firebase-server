import Foundation

/// Cloud Audit Logs イベントペイロード
///
/// Eventarc トリガー: `google.cloud.audit.log.v1.written`
///
/// Cloud Audit Logs は Identity Platform (Firebase Auth) などのサービスからの
/// 監査ログをCloud RunにルーティングするためのEventarcトリガーで使用されます。
///
/// ## Firebase Auth ユーザー作成イベントの受信
///
/// Firebase Auth は直接 Eventarc プロバイダーではありませんが、
/// Cloud Audit Logs 経由でユーザー作成イベントを受信できます。
///
/// ### gcloud トリガー作成コマンド
/// ```bash
/// gcloud eventarc triggers create auth-user-signup \
///   --location=asia-northeast1 \
///   --destination-run-service=your-service \
///   --destination-run-region=asia-northeast1 \
///   --destination-run-path="/webhooks/auth/user-created" \
///   --event-filters="type=google.cloud.audit.log.v1.written" \
///   --event-filters="serviceName=identitytoolkit.googleapis.com" \
///   --event-filters="methodName=google.cloud.identitytoolkit.v1.AuthenticationService.SignUp" \
///   --service-account="PROJECT_NUMBER-compute@developer.gserviceaccount.com"
/// ```
///
/// ### 使用例
/// ```swift
/// routes.webhook("user-created", body: CloudAuditLogEvent.self) { request in
///     let headers = CloudEventHeaders(from: request.headers.all)
///     let event = request.body
///
///     // Identity Platform SignUp の場合
///     if let response = event.protoPayload?.response,
///        let localId = response["localId"]?.stringValue {
///         print("New user signed up: \(localId)")
///     }
///
///     return HTTPStatus.ok
/// }
/// ```
///
/// ## 参考
/// - [Cloud Audit Logs Overview](https://cloud.google.com/logging/docs/audit)
/// - [Identity Platform Audit Logging](https://cloud.google.com/identity-platform/docs/audit-logging)
public struct CloudAuditLogEvent: Codable, Sendable {
    /// 監査ログペイロード
    public let protoPayload: AuditLog?

    /// ログ名
    /// 例: `projects/my-project/logs/cloudaudit.googleapis.com%2Factivity`
    public let logName: String?

    /// ログの重要度
    public let severity: String?

    /// イベント発生時刻
    public let timestamp: String?

    /// リソース情報
    public let resource: Resource?

    /// 監査ログの詳細
    public struct AuditLog: Codable, Sendable {
        /// ログタイプ
        /// 例: `type.googleapis.com/google.cloud.audit.AuditLog`
        public let type: String?

        /// サービス名
        /// 例: `identitytoolkit.googleapis.com`
        public let serviceName: String?

        /// メソッド名
        /// 例: `google.cloud.identitytoolkit.v1.AuthenticationService.SignUp`
        public let methodName: String?

        /// リソース名
        /// 例: `projects/my-project/accounts/USER_ID`
        public let resourceName: String?

        /// 認証情報
        public let authenticationInfo: AuthenticationInfo?

        /// リクエストメタデータ
        public let requestMetadata: RequestMetadata?

        /// リクエストデータ（動的型）
        public let request: DynamicValue?

        /// レスポンスデータ（動的型）
        public let response: DynamicValue?

        /// ステータス
        public let status: Status?

        private enum CodingKeys: String, CodingKey {
            case type = "@type"
            case serviceName
            case methodName
            case resourceName
            case authenticationInfo
            case requestMetadata
            case request
            case response
            case status
        }
    }

    /// 認証情報
    public struct AuthenticationInfo: Codable, Sendable {
        /// プリンシパルのメールアドレス
        public let principalEmail: String?

        /// サービスアカウントキー名
        public let serviceAccountKeyName: String?
    }

    /// リクエストメタデータ
    public struct RequestMetadata: Codable, Sendable {
        /// 呼び出し元IPアドレス
        public let callerIp: String?

        /// ユーザーエージェント
        public let callerSuppliedUserAgent: String?
    }

    /// ステータス情報
    public struct Status: Codable, Sendable {
        /// ステータスコード（0 = 成功）
        public let code: Int?

        /// ステータスメッセージ
        public let message: String?
    }

    /// リソース情報
    public struct Resource: Codable, Sendable {
        /// リソースタイプ
        public let type: String?

        /// リソースラベル
        public let labels: [String: String]?
    }
}

// MARK: - Dynamic Value

/// 動的な値を表現する型
///
/// Cloud Audit Logs の request/response フィールドは
/// `google.protobuf.Struct` 形式で、任意の構造を持ちます。
public struct DynamicValue: Codable, Sendable {
    /// 値の型
    public let type: String?

    /// 内部の値（フラットな辞書として格納）
    private let rawValues: [String: JSONValue]?

    /// 文字列値を取得
    public subscript(_ key: String) -> JSONValue? {
        rawValues?[key]
    }

    private enum CodingKeys: String, CodingKey {
        case type = "@type"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)

        // 動的に全てのキーをデコード
        let dynamicContainer = try decoder.container(keyedBy: DynamicCodingKey.self)
        var values: [String: JSONValue] = [:]
        for key in dynamicContainer.allKeys {
            if key.stringValue == "@type" { continue }
            if let value = try? dynamicContainer.decode(JSONValue.self, forKey: key) {
                values[key.stringValue] = value
            }
        }
        self.rawValues = values.isEmpty ? nil : values
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(type, forKey: .type)

        if let rawValues = rawValues {
            var dynamicContainer = encoder.container(keyedBy: DynamicCodingKey.self)
            for (key, value) in rawValues {
                if let codingKey = DynamicCodingKey(stringValue: key) {
                    try dynamicContainer.encode(value, forKey: codingKey)
                }
            }
        }
    }

    /// 全てのキーを取得
    public var keys: [String] {
        rawValues?.keys.map { $0 } ?? []
    }
}

/// 動的なコーディングキー
private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

/// JSON値を表現する型
public enum JSONValue: Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])

    /// 文字列として取得
    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    /// 整数として取得
    public var intValue: Int? {
        if case .int(let value) = self { return value }
        return nil
    }

    /// ブールとして取得
    public var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    /// オブジェクトとして取得
    public var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.typeMismatch(
                JSONValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unable to decode JSONValue"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}

// MARK: - CloudEventHeaders Extension

extension CloudEventHeaders {
    /// Cloud Audit Logs イベントタイプ
    public enum AuditLogEventType {
        /// 監査ログ書き込みイベント
        public static let logWritten = "google.cloud.audit.log.v1.written"
    }

    /// Identity Platform (Firebase Auth) サービス名
    public enum IdentityPlatformService {
        /// サービス名
        public static let serviceName = "identitytoolkit.googleapis.com"

        /// ユーザーサインアップメソッド
        public static let signUpMethod = "google.cloud.identitytoolkit.v1.AuthenticationService.SignUp"

        /// ユーザー削除メソッド
        public static let deleteAccountMethod = "google.cloud.identitytoolkit.v1.AuthenticationService.DeleteAccount"
    }
}

// MARK: - Convenience Extensions

extension CloudAuditLogEvent {
    /// Identity Platform SignUp イベントかどうかを判定
    public var isIdentityPlatformSignUp: Bool {
        guard let payload = protoPayload else { return false }
        return payload.serviceName == CloudEventHeaders.IdentityPlatformService.serviceName
            && payload.methodName == CloudEventHeaders.IdentityPlatformService.signUpMethod
    }

    /// Identity Platform DeleteAccount イベントかどうかを判定
    public var isIdentityPlatformDeleteAccount: Bool {
        guard let payload = protoPayload else { return false }
        return payload.serviceName == CloudEventHeaders.IdentityPlatformService.serviceName
            && payload.methodName == CloudEventHeaders.IdentityPlatformService.deleteAccountMethod
    }

    /// サインアップしたユーザーIDを取得
    ///
    /// Identity Platform SignUp イベントの場合、レスポンスからlocalIdを抽出します。
    public var signedUpUserId: String? {
        guard isIdentityPlatformSignUp,
              let response = protoPayload?.response,
              let localId = response["localId"]?.stringValue
        else { return nil }
        return localId
    }

    /// サインアップしたユーザーのメールアドレスを取得
    public var signedUpUserEmail: String? {
        guard isIdentityPlatformSignUp,
              let response = protoPayload?.response,
              let email = response["email"]?.stringValue
        else { return nil }
        return email
    }
}
