import Foundation

/// The JSON payload of a Cloud Audit Logs entry delivered by Eventarc.
///
/// Eventarc trigger: `google.cloud.audit.log.v1.written`.
///
/// Cloud Audit Logs is what routes activity from services such as Identity Platform (Firebase
/// Auth) to Cloud Run: the trigger filters on the audited service and method, and the audited
/// call's own request and response ride along as `google.protobuf.Struct`, so they are read
/// dynamically rather than through fixed properties.
///
/// ## Receiving Firebase Auth user creations
///
/// Firebase Auth is not a direct Eventarc provider, but its sign-ups are audited, so filtering
/// audit logs on the Identity Platform `SignUp` method delivers user creations all the same.
///
/// ### Creating the trigger with gcloud
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
/// ### Example
/// ```swift
/// routes.webhook("user-created", body: CloudAuditLogEvent.self) { request in
///     let headers = CloudEventHeaders(from: request.headers.all)
///     let event = request.body
///
///     // An Identity Platform SignUp
///     if let response = event.protoPayload?.response,
///        let localId = response["localId"]?.stringValue {
///         print("New user signed up: \(localId)")
///     }
///
///     return HTTPStatus.ok
/// }
/// ```
///
/// ## References
/// - [Cloud Audit Logs Overview](https://cloud.google.com/logging/docs/audit)
/// - [Identity Platform Audit Logging](https://cloud.google.com/identity-platform/docs/audit-logging)
public struct CloudAuditLogEvent: Codable, Sendable {
    /// The audit record itself, holding the audited service, method, request, and response.
    ///
    /// Everything worth branching on lives here; the outer fields only describe the log entry.
    public let protoPayload: AuditLog?

    /// The log the entry was written to, for example
    /// `projects/my-project/logs/cloudaudit.googleapis.com%2Factivity`.
    ///
    /// The `%2F` is a literal part of the name: the log ID is URL-encoded inside it.
    public let logName: String?

    /// The Cloud Logging severity as a raw string, such as `NOTICE` or `ERROR`.
    public let severity: String?

    /// When the audited operation was logged, in RFC 3339 format.
    public let timestamp: String?

    /// The monitored resource the audited call acted on.
    public let resource: Resource?

    /// The audit record carried in `protoPayload`.
    public struct AuditLog: Codable, Sendable {
        /// The payload's protobuf type URL, decoded from the `@type` key, normally
        /// `type.googleapis.com/google.cloud.audit.AuditLog`.
        public let type: String?

        /// The audited service, for example `identitytoolkit.googleapis.com`.
        ///
        /// This is what an Eventarc `serviceName` event filter matches.
        public let serviceName: String?

        /// The audited method, for example
        /// `google.cloud.identitytoolkit.v1.AuthenticationService.SignUp`.
        ///
        /// This is what an Eventarc `methodName` event filter matches, and it is how you tell a
        /// sign-up from an account deletion.
        public let methodName: String?

        /// The resource the call targeted, for example `projects/my-project/accounts/USER_ID`.
        public let resourceName: String?

        /// The identity that made the audited call, when the service reports one.
        public let authenticationInfo: AuthenticationInfo?

        /// Transport-level details about the caller, such as its IP address and user agent.
        public let requestMetadata: RequestMetadata?

        /// The audited call's request, kept dynamic because its shape depends on the method.
        ///
        /// Services redact or omit fields here, so a key present for one method may be missing
        /// for another.
        public let request: DynamicValue?

        /// The audited call's response, kept dynamic because its shape depends on the method.
        ///
        /// An Identity Platform `SignUp` puts the new account's `localId` and `email` here.
        public let response: DynamicValue?

        /// The outcome of the call. A `nil` status, or a `code` of 0, means it succeeded.
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

    /// Who the audited call authenticated as.
    public struct AuthenticationInfo: Codable, Sendable {
        /// The authenticated principal's email address, or `nil` when the call had no principal
        /// identity, which is the usual case for an end user signing themselves up.
        public let principalEmail: String?

        /// The service account key the caller authenticated with, when one was used.
        public let serviceAccountKeyName: String?
    }

    /// Transport-level details about the caller.
    public struct RequestMetadata: Codable, Sendable {
        public let callerIp: String?

        /// The user agent the client sent. It is client-supplied and unverified, so do not make
        /// authorization decisions on it.
        public let callerSuppliedUserAgent: String?
    }

    /// The outcome of the audited call.
    public struct Status: Codable, Sendable {
        /// The canonical gRPC status code, where 0 means success.
        ///
        /// Successful entries usually omit the field entirely, so `nil` also reads as success.
        public let code: Int?

        /// The error message, present only when the call failed.
        public let message: String?
    }

    /// The monitored resource the audited call acted on.
    public struct Resource: Codable, Sendable {
        /// The monitored resource type reported by Cloud Logging.
        public let type: String?

        /// The resource's labels, such as `project_id`, keyed by label name.
        public let labels: [String: String]?
    }
}

// MARK: - Dynamic Value

/// A schema-free object decoded key by key.
///
/// The `request` and `response` fields of a Cloud Audit Logs entry are `google.protobuf.Struct`,
/// so their shape depends on the audited method and cannot be modelled as properties. This type
/// pulls the `@type` key out into `type` and keeps every other top-level key as a `JSONValue`
/// reachable by subscript. Keys whose values fail to decode are dropped silently rather than
/// throwing, so a missing key means either "not sent" or "not decodable".
public struct DynamicValue: Codable, Sendable {
    /// The protobuf type URL taken from the object's `@type` key, when it has one.
    public let type: String?

    /// Every top-level key except `@type`, or `nil` when the object had no other keys.
    private let rawValues: [String: JSONValue]?

    /// Returns the value stored under a top-level key, or `nil` if the key was absent.
    ///
    /// The lookup is exact and only reaches the top level; step into a `.object` value to go
    /// deeper. Asking for `@type` always returns `nil` because it is kept in `type` instead.
    public subscript(_ key: String) -> JSONValue? {
        rawValues?[key]
    }

    private enum CodingKeys: String, CodingKey {
        case type = "@type"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)

        // Decode every key the object happens to carry
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

    /// The top-level keys the object carried, in no particular order.
    ///
    /// `@type` is not among them, and the array is empty rather than `nil` when nothing decoded.
    public var keys: [String] {
        rawValues?.keys.map { $0 } ?? []
    }
}

/// A coding key that accepts any name, so an object with an unknown schema can be walked.
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

/// One JSON value of any kind, preserved as decoded.
///
/// Decoding tries the cases in a fixed order — null, bool, integer, double, string, array,
/// object — so a whole number always lands in `int` and never in `double`. The accessors below
/// never convert: `intValue` on a `double`, or on a string holding digits, is `nil`. There is no
/// accessor for `double`, `array`, or `null`; match on the case for those.
public enum JSONValue: Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])

    /// The string this value holds, or `nil` if it holds anything else.
    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    /// The integer this value holds, or `nil` if it holds anything else, including a fractional
    /// number or a string of digits.
    public var intValue: Int? {
        if case .int(let value) = self { return value }
        return nil
    }

    /// The boolean this value holds, or `nil` if it holds anything else.
    public var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    /// The object this value holds, or `nil` if it holds anything else. Use it to step into a
    /// nested payload one level at a time.
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
    /// The `ce-type` value every Cloud Audit Logs delivery carries.
    ///
    /// It is the same for all audited services, so the header alone never tells you which
    /// operation happened — match on the payload's service and method names for that.
    public enum AuditLogEventType {
        public static let logWritten = "google.cloud.audit.log.v1.written"
    }

    /// The Identity Platform (Firebase Auth) service and method names to filter audit logs on.
    ///
    /// These match `AuditLog.serviceName` and `AuditLog.methodName`, and are the values an
    /// Eventarc trigger takes as its `serviceName` and `methodName` event filters.
    public enum IdentityPlatformService {
        public static let serviceName = "identitytoolkit.googleapis.com"

        /// The method audited when a user signs up, which is how a user creation arrives.
        public static let signUpMethod = "google.cloud.identitytoolkit.v1.AuthenticationService.SignUp"

        /// The method audited when an account is deleted.
        public static let deleteAccountMethod = "google.cloud.identitytoolkit.v1.AuthenticationService.DeleteAccount"
    }
}

// MARK: - Convenience Extensions

extension CloudAuditLogEvent {
    /// Whether this entry audits an Identity Platform sign-up.
    ///
    /// Matched on the payload's service and method names only, so it is `false` when there is no
    /// payload, and `true` even for a sign-up that failed — check `protoPayload?.status` before
    /// treating it as a new account.
    public var isIdentityPlatformSignUp: Bool {
        guard let payload = protoPayload else { return false }
        return payload.serviceName == CloudEventHeaders.IdentityPlatformService.serviceName
            && payload.methodName == CloudEventHeaders.IdentityPlatformService.signUpMethod
    }

    /// Whether this entry audits an Identity Platform account deletion.
    ///
    /// Matched the same way as a sign-up, so the same caveats apply: no payload means `false`,
    /// and a failed deletion still matches.
    public var isIdentityPlatformDeleteAccount: Bool {
        guard let payload = protoPayload else { return false }
        return payload.serviceName == CloudEventHeaders.IdentityPlatformService.serviceName
            && payload.methodName == CloudEventHeaders.IdentityPlatformService.deleteAccountMethod
    }

    /// The Firebase user ID of the account created by this sign-up.
    ///
    /// Read from the audited response's `localId`, which is the same value Firebase Auth calls
    /// `uid`. `nil` when the entry is not an Identity Platform sign-up, when the response was
    /// not delivered, or when the field is not a string.
    public var signedUpUserId: String? {
        guard isIdentityPlatformSignUp,
              let response = protoPayload?.response,
              let localId = response["localId"]?.stringValue
        else { return nil }
        return localId
    }

    /// The email address of the account created by this sign-up.
    ///
    /// `nil` for the same reasons as the user ID, and also for sign-up methods that carry no
    /// address, such as anonymous or phone sign-in.
    public var signedUpUserEmail: String? {
        guard isIdentityPlatformSignUp,
              let response = protoPayload?.response,
              let email = response["email"]?.stringValue
        else { return nil }
        return email
    }
}
