import Foundation

/// Firestore REST APIで使用される値型
///
/// Firestore REST APIは独自のJSON形式を使用する:
/// ```json
/// {
///   "stringValue": "hello",
///   "integerValue": "123",
///   "mapValue": { "fields": { ... } }
/// }
/// ```
///
/// 参考: https://cloud.google.com/firestore/docs/reference/rest/v1/Value
public enum FirestoreValue: Sendable, Hashable {
    /// null値
    case null

    /// ブール値
    case boolean(Bool)

    /// 整数値（64ビット）
    case integer(Int64)

    /// 浮動小数点値
    case double(Double)

    /// タイムスタンプ（RFC3339形式）
    case timestamp(Date)

    /// 文字列（最大1MiB - 89バイト）
    case string(String)

    /// バイト列（Base64エンコード、最大1MiB - 89バイト）
    case bytes(Data)

    /// ドキュメント参照
    case reference(String)

    /// 地理座標
    case geoPoint(latitude: Double, longitude: Double)

    /// 配列（配列のネストは不可）
    case array([FirestoreValue])

    /// マップ（オブジェクト）
    case map([String: FirestoreValue])
}

// MARK: - JSON Encoding

extension FirestoreValue {
    /// REST API用のJSON辞書に変換
    public func toJSON() -> [String: Any] {
        switch self {
        case .null:
            return ["nullValue": NSNull()]

        case .boolean(let value):
            return ["booleanValue": value]

        case .integer(let value):
            // Firestore REST APIは整数を文字列として扱う
            return ["integerValue": String(value)]

        case .double(let value):
            return ["doubleValue": value]

        case .timestamp(let date):
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return ["timestampValue": formatter.string(from: date)]

        case .string(let value):
            return ["stringValue": value]

        case .bytes(let data):
            return ["bytesValue": data.base64EncodedString()]

        case .reference(let path):
            return ["referenceValue": path]

        case .geoPoint(let latitude, let longitude):
            return ["geoPointValue": ["latitude": latitude, "longitude": longitude]]

        case .array(let values):
            return ["arrayValue": ["values": values.map { $0.toJSON() }]]

        case .map(let fields):
            var jsonFields: [String: Any] = [:]
            for (key, value) in fields {
                jsonFields[key] = value.toJSON()
            }
            return ["mapValue": ["fields": jsonFields]]
        }
    }
}

// MARK: - JSON Decoding

extension FirestoreValue {
    /// REST APIのJSONレスポンスからパース
    public static func fromJSON(_ json: [String: Any]) throws -> FirestoreValue {
        if json["nullValue"] != nil {
            return .null
        }

        if let value = json["booleanValue"] as? Bool {
            return .boolean(value)
        }

        if let value = json["integerValue"] as? String {
            guard let intValue = Int64(value) else {
                throw FirestoreValueError.invalidIntegerValue(value)
            }
            return .integer(intValue)
        }

        // integerValueが数値として来る場合もある
        if let value = json["integerValue"] as? Int64 {
            return .integer(value)
        }
        if let value = json["integerValue"] as? Int {
            return .integer(Int64(value))
        }

        if let value = json["doubleValue"] as? Double {
            return .double(value)
        }

        if let value = json["timestampValue"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let date = formatter.date(from: value) else {
                // フラクショナル秒なしで再試行
                formatter.formatOptions = [.withInternetDateTime]
                guard let date = formatter.date(from: value) else {
                    throw FirestoreValueError.invalidTimestamp(value)
                }
                return .timestamp(date)
            }
            return .timestamp(date)
        }

        if let value = json["stringValue"] as? String {
            return .string(value)
        }

        if let value = json["bytesValue"] as? String {
            guard let data = Data(base64Encoded: value) else {
                throw FirestoreValueError.invalidBase64(value)
            }
            return .bytes(data)
        }

        if let value = json["referenceValue"] as? String {
            return .reference(value)
        }

        if let geoPoint = json["geoPointValue"] as? [String: Any],
           let latitude = geoPoint["latitude"] as? Double,
           let longitude = geoPoint["longitude"] as? Double {
            return .geoPoint(latitude: latitude, longitude: longitude)
        }

        if let arrayValue = json["arrayValue"] as? [String: Any],
           let values = arrayValue["values"] as? [[String: Any]] {
            let parsed = try values.map { try FirestoreValue.fromJSON($0) }
            return .array(parsed)
        }

        // 空の配列
        if let arrayValue = json["arrayValue"] as? [String: Any],
           arrayValue["values"] == nil {
            return .array([])
        }

        if let mapValue = json["mapValue"] as? [String: Any],
           let fields = mapValue["fields"] as? [String: [String: Any]] {
            var parsed: [String: FirestoreValue] = [:]
            for (key, value) in fields {
                parsed[key] = try FirestoreValue.fromJSON(value)
            }
            return .map(parsed)
        }

        // 空のマップ
        if let mapValue = json["mapValue"] as? [String: Any],
           mapValue["fields"] == nil {
            return .map([:])
        }

        throw FirestoreValueError.unknownValueType(String(describing: json))
    }
}

// MARK: - Error

/// FirestoreValue変換エラー
public enum FirestoreValueError: Error, Sendable {
    case invalidIntegerValue(String)
    case invalidTimestamp(String)
    case invalidBase64(String)
    case unknownValueType(String)
}

extension FirestoreValueError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidIntegerValue(let value):
            return "Invalid integer value: \(value)"
        case .invalidTimestamp(let value):
            return "Invalid timestamp: \(value)"
        case .invalidBase64(let value):
            return "Invalid base64 string: \(value)"
        case .unknownValueType(let description):
            return "Unknown value type in JSON: \(description)"
        }
    }
}
