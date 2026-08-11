import Foundation

/// One field value in the Firestore REST wire format.
///
/// The REST API tags every value with its type, as a JSON object holding exactly one key:
/// ```json
/// {
///   "stringValue": "hello",
///   "integerValue": "123",
///   "mapValue": { "fields": { ... } }
/// }
/// ```
///
/// See https://cloud.google.com/firestore/docs/reference/rest/v1/Value
public enum FirestoreValue: Sendable, Hashable {
    /// An explicit null, written as `nullValue`.
    case null

    /// A `booleanValue`.
    case boolean(Bool)

    /// A 64-bit signed `integerValue`, which travels as a JSON string, not a number.
    case integer(Int64)

    /// A `doubleValue`.
    case double(Double)

    /// A `timestampValue` in RFC 3339 form.
    ///
    /// Encoding writes milliseconds, so the microsecond precision Firestore stores does not
    /// survive a round trip through this type.
    case timestamp(Date)

    /// A `stringValue`, which Firestore caps at 1 MiB − 89 bytes.
    case string(String)

    /// A `bytesValue`, base64 encoded on the wire and capped at 1 MiB − 89 bytes.
    case bytes(Data)

    /// A `referenceValue`, holding a document's full resource name.
    ///
    /// The path is the complete name — `projects/p/databases/(default)/documents/users/abc` —
    /// not a relative one.
    case reference(String)

    /// A `geoPointValue`, in degrees.
    case geoPoint(latitude: Double, longitude: Double)

    /// An `arrayValue`.
    ///
    /// Firestore refuses an array placed directly inside another array. Nothing here checks
    /// for it, so such a value encodes happily and the write fails server-side.
    case array([FirestoreValue])

    /// A `mapValue`, whose nesting Firestore limits to 20 levels of fields.
    case map([String: FirestoreValue])
}

// MARK: - JSON Encoding

extension FirestoreValue {
    /// Renders the value as its tagged REST JSON object.
    public func toJSON() -> [String: Any] {
        switch self {
        case .null:
            return ["nullValue": NSNull()]

        case .boolean(let value):
            return ["booleanValue": value]

        case .integer(let value):
            // The Firestore REST API carries integers as strings
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
    /// Reads one tagged value out of a REST response.
    ///
    /// The type keys are tried in a fixed order, and `integerValue` is accepted both as the
    /// string the API documents and as a bare JSON number. An `arrayValue` or `mapValue` with
    /// no payload decodes as empty rather than failing.
    ///
    /// - Throws: `FirestoreValueError.unknownValueType` when no type key is recognised, and
    ///   the matching `invalidIntegerValue` / `invalidTimestamp` / `invalidBase64` when a key
    ///   is present but its payload cannot be parsed.
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

        // integerValue sometimes arrives as a number
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
                // Retry without fractional seconds
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

        // Empty array
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

        // Empty map
        if let mapValue = json["mapValue"] as? [String: Any],
           mapValue["fields"] == nil {
            return .map([:])
        }

        throw FirestoreValueError.unknownValueType(String(describing: json))
    }
}

// MARK: - Error

/// A REST value that could not be read.
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

// MARK: - FirestoreValueConvertible

/// A Swift type that can stand in for a Firestore value.
///
/// This is what lets the filter DSL take ordinary Swift literals on the right-hand side of a
/// comparison. References and geo points have no conforming Swift type, so pass those as
/// `FirestoreValue` directly.
///
/// ```swift
/// query.filter {
///     Field("name") == "John"  // String → FirestoreValue.string
///     Field("age") >= 18       // Int → FirestoreValue.integer
/// }
/// ```
public protocol FirestoreValueConvertible: Sendable {
    func toFirestoreValue() -> FirestoreValue
}

// MARK: - Standard Type Conformances

extension String: FirestoreValueConvertible {
    public func toFirestoreValue() -> FirestoreValue {
        .string(self)
    }
}

extension Bool: FirestoreValueConvertible {
    public func toFirestoreValue() -> FirestoreValue {
        .boolean(self)
    }
}

extension Int: FirestoreValueConvertible {
    public func toFirestoreValue() -> FirestoreValue {
        .integer(Int64(self))
    }
}

extension Int64: FirestoreValueConvertible {
    public func toFirestoreValue() -> FirestoreValue {
        .integer(self)
    }
}

extension Int32: FirestoreValueConvertible {
    public func toFirestoreValue() -> FirestoreValue {
        .integer(Int64(self))
    }
}

extension Double: FirestoreValueConvertible {
    public func toFirestoreValue() -> FirestoreValue {
        .double(self)
    }
}

extension Float: FirestoreValueConvertible {
    public func toFirestoreValue() -> FirestoreValue {
        .double(Double(self))
    }
}

extension Date: FirestoreValueConvertible {
    public func toFirestoreValue() -> FirestoreValue {
        .timestamp(self)
    }
}

extension Data: FirestoreValueConvertible {
    public func toFirestoreValue() -> FirestoreValue {
        .bytes(self)
    }
}

extension FirestoreValue: FirestoreValueConvertible {
    public func toFirestoreValue() -> FirestoreValue {
        self
    }
}

extension Array: FirestoreValueConvertible where Element: FirestoreValueConvertible {
    public func toFirestoreValue() -> FirestoreValue {
        .array(self.map { $0.toFirestoreValue() })
    }
}
