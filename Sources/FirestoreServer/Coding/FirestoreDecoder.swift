import Foundation

/// Decodes Firestore REST field values into `Decodable` types.
///
/// A `timestampValue` decodes only into `Date` and a `bytesValue` only into `Data`; any other
/// mismatch between the stored value and the requested type throws
/// `FirestoreDecodingError.typeMismatch`, with two deliberate exceptions: a field absent from
/// the document decodes as `nil` for an optional property, and an `integerValue` widens into
/// `Double` and `Float`.
///
/// - Note: The narrower integer types are read as `Int64` and converted with non-failable
///   initializers, so a stored value that does not fit the property's type — a negative number
///   read into `UInt`, or 300 read into `Int8` — traps instead of throwing.
///
/// ```swift
/// struct User: Codable {
///     let name: String
///     let age: Int
/// }
///
/// let decoder = FirestoreDecoder()
/// let user: User = try decoder.decode(User.self, from: firestoreDocument)
///
/// // Converting from snake_case
/// struct UserProfile: Codable {
///     let userId: String      // "user_id" in Firestore
///     let displayName: String // "display_name" in Firestore
/// }
/// let snakeCaseDecoder = FirestoreDecoder(keyDecodingStrategy: .convertFromSnakeCase)
/// let profile: UserProfile = try snakeCaseDecoder.decode(UserProfile.self, from: fields)
/// ```
public struct FirestoreDecoder: Sendable {
    public let keyDecodingStrategy: KeyDecodingStrategy

    /// - Parameter keyDecodingStrategy: How field names are matched to property names. Defaults
    ///   to matching them verbatim.
    public init(keyDecodingStrategy: KeyDecodingStrategy = .useDefaultKeys) {
        self.keyDecodingStrategy = keyDecodingStrategy
    }

    /// Decodes a document's fields into a value.
    /// - Parameters:
    ///   - type: The type to decode into.
    ///   - document: The document to read. Only its `fields` are used — `name`, `createTime`,
    ///     and `updateTime` are not exposed to the decoded type, so a model that needs its own
    ///     ID has to take it from `documentId` separately.
    public func decode<T: Decodable>(_ type: T.Type, from document: FirestoreDocument) throws -> T {
        try decode(type, from: document.fields)
    }

    /// Decodes a field map into a value.
    /// - Parameters:
    ///   - type: The type to decode into.
    ///   - fields: The field map, as it appears in a document's `fields`.
    public func decode<T: Decodable>(_ type: T.Type, from fields: [String: FirestoreValue]) throws -> T {
        let decoder = _FirestoreDecoder(value: .map(fields), keyDecodingStrategy: keyDecodingStrategy)
        return try T(from: decoder)
    }

    /// Decodes a single field value, for anything that is not a whole document.
    /// - Parameters:
    ///   - type: The type to decode into.
    ///   - value: The value to read, which may be a scalar or an array as well as a map.
    public func decodeValue<T: Decodable>(_ type: T.Type, from value: FirestoreValue) throws -> T {
        let decoder = _FirestoreDecoder(value: value, keyDecodingStrategy: keyDecodingStrategy)
        return try T(from: decoder)
    }
}

// MARK: - Internal Decoder Implementation

private final class _FirestoreDecoder: Decoder {
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]
    let value: FirestoreValue
    let keyDecodingStrategy: KeyDecodingStrategy

    init(value: FirestoreValue, keyDecodingStrategy: KeyDecodingStrategy = .useDefaultKeys) {
        self.value = value
        self.keyDecodingStrategy = keyDecodingStrategy
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard case .map(let fields) = value else {
            throw FirestoreDecodingError.typeMismatch(expected: "map", actual: value)
        }
        return KeyedDecodingContainer(FirestoreKeyedDecodingContainer<Key>(
            fields: fields,
            codingPath: codingPath,
            keyDecodingStrategy: keyDecodingStrategy
        ))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard case .array(let values) = value else {
            throw FirestoreDecodingError.typeMismatch(expected: "array", actual: value)
        }
        return FirestoreUnkeyedDecodingContainer(
            values: values,
            codingPath: codingPath,
            keyDecodingStrategy: keyDecodingStrategy
        )
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        FirestoreSingleValueDecodingContainer(
            codingPath: codingPath,
            value: value,
            keyDecodingStrategy: keyDecodingStrategy
        )
    }
}

// MARK: - Keyed Container

private struct FirestoreKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    var codingPath: [CodingKey]
    var allKeys: [Key] {
        fields.keys.compactMap { firestoreKey in
            // Turn each Firestore field name back into a Swift property name
            let swiftKey = keyDecodingStrategy.decode(firestoreKey)
            return Key(stringValue: swiftKey)
        }
    }

    let fields: [String: FirestoreValue]
    let keyDecodingStrategy: KeyDecodingStrategy

    init(fields: [String: FirestoreValue], codingPath: [CodingKey], keyDecodingStrategy: KeyDecodingStrategy) {
        self.fields = fields
        self.codingPath = codingPath
        self.keyDecodingStrategy = keyDecodingStrategy
    }

    func contains(_ key: Key) -> Bool {
        getFirestoreKey(for: key) != nil
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        guard let firestoreKey = getFirestoreKey(for: key),
              let value = fields[firestoreKey] else {
            return true
        }
        if case .null = value {
            return true
        }
        return false
    }

    /// Finds the field name that holds the value for a property.
    ///
    /// An exact match always wins, whatever the strategy; only then is the strategy consulted.
    /// - Parameter key: The Swift property name.
    /// - Returns: The Firestore field name, or `nil` when the document has no such field.
    private func getFirestoreKey(for key: Key) -> String? {
        let swiftKeyString = key.stringValue

        // Try an exact match first
        if fields[swiftKeyString] != nil {
            return swiftKeyString
        }

        // Otherwise resolve through the strategy
        switch keyDecodingStrategy {
        case .useDefaultKeys:
            return nil
        case .convertFromSnakeCase:
            // Convert the camelCase property name to snake_case and look that up
            let snakeCaseKey = swiftKeyString.convertToSnakeCase()
            if fields[snakeCaseKey] != nil {
                return snakeCaseKey
            }
            return nil
        case .custom:
            // A custom transform cannot be inverted, so convert every field name until one matches
            for firestoreKey in fields.keys {
                let decodedKey = keyDecodingStrategy.decode(firestoreKey)
                if decodedKey == swiftKeyString {
                    return firestoreKey
                }
            }
            return nil
        }
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        guard case .boolean(let value) = try getValue(for: key) else {
            throw FirestoreDecodingError.typeMismatch(expected: "boolean", actual: try getValue(for: key))
        }
        return value
    }

    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        guard case .string(let value) = try getValue(for: key) else {
            throw FirestoreDecodingError.typeMismatch(expected: "string", actual: try getValue(for: key))
        }
        return value
    }

    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        let value = try getValue(for: key)
        switch value {
        case .double(let d): return d
        case .integer(let i): return Double(i)
        default:
            throw FirestoreDecodingError.typeMismatch(expected: "double", actual: value)
        }
    }

    func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        Float(try decode(Double.self, forKey: key))
    }

    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        Int(try decode(Int64.self, forKey: key))
    }

    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        Int8(try decode(Int64.self, forKey: key))
    }

    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        Int16(try decode(Int64.self, forKey: key))
    }

    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        Int32(try decode(Int64.self, forKey: key))
    }

    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        guard case .integer(let value) = try getValue(for: key) else {
            throw FirestoreDecodingError.typeMismatch(expected: "integer", actual: try getValue(for: key))
        }
        return value
    }

    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        UInt(try decode(Int64.self, forKey: key))
    }

    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        UInt8(try decode(Int64.self, forKey: key))
    }

    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        UInt16(try decode(Int64.self, forKey: key))
    }

    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        UInt32(try decode(Int64.self, forKey: key))
    }

    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        UInt64(try decode(Int64.self, forKey: key))
    }

    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        let value = try getValue(for: key)

        // Types with a Firestore value of their own
        if type == Date.self {
            guard case .timestamp(let date) = value else {
                throw FirestoreDecodingError.typeMismatch(expected: "timestamp", actual: value)
            }
            return date as! T
        }

        if type == Data.self {
            guard case .bytes(let data) = value else {
                throw FirestoreDecodingError.typeMismatch(expected: "bytes", actual: value)
            }
            return data as! T
        }

        // Everything else re-enters the decoder
        let decoder = _FirestoreDecoder(value: value, keyDecodingStrategy: keyDecodingStrategy)
        return try T(from: decoder)
    }

    func nestedContainer<NestedKey: CodingKey>(
        keyedBy type: NestedKey.Type,
        forKey key: Key
    ) throws -> KeyedDecodingContainer<NestedKey> {
        guard case .map(let nestedFields) = try getValue(for: key) else {
            throw FirestoreDecodingError.typeMismatch(expected: "map", actual: try getValue(for: key))
        }
        return KeyedDecodingContainer(
            FirestoreKeyedDecodingContainer<NestedKey>(
                fields: nestedFields,
                codingPath: codingPath + [key],
                keyDecodingStrategy: keyDecodingStrategy
            )
        )
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        guard case .array(let values) = try getValue(for: key) else {
            throw FirestoreDecodingError.typeMismatch(expected: "array", actual: try getValue(for: key))
        }
        return FirestoreUnkeyedDecodingContainer(
            values: values,
            codingPath: codingPath + [key],
            keyDecodingStrategy: keyDecodingStrategy
        )
    }

    func superDecoder() throws -> Decoder {
        _FirestoreDecoder(value: .map(fields), keyDecodingStrategy: keyDecodingStrategy)
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        _FirestoreDecoder(value: try getValue(for: key), keyDecodingStrategy: keyDecodingStrategy)
    }

    private func getValue(for key: Key) throws -> FirestoreValue {
        guard let firestoreKey = getFirestoreKey(for: key),
              let value = fields[firestoreKey] else {
            throw FirestoreDecodingError.keyNotFound(key.stringValue)
        }
        return value
    }
}

// MARK: - Unkeyed Container

private struct FirestoreUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    var codingPath: [CodingKey]
    var count: Int? { values.count }
    var isAtEnd: Bool { currentIndex >= values.count }
    var currentIndex: Int = 0

    let values: [FirestoreValue]
    let keyDecodingStrategy: KeyDecodingStrategy

    init(values: [FirestoreValue], codingPath: [CodingKey], keyDecodingStrategy: KeyDecodingStrategy = .useDefaultKeys) {
        self.values = values
        self.codingPath = codingPath
        self.keyDecodingStrategy = keyDecodingStrategy
    }

    mutating func decodeNil() throws -> Bool {
        guard !isAtEnd else {
            throw FirestoreDecodingError.outOfBounds(currentIndex)
        }
        if case .null = values[currentIndex] {
            currentIndex += 1
            return true
        }
        return false
    }

    mutating func decode(_ type: Bool.Type) throws -> Bool {
        guard case .boolean(let value) = try getNextValue() else {
            throw FirestoreDecodingError.typeMismatch(expected: "boolean", actual: values[currentIndex - 1])
        }
        return value
    }

    mutating func decode(_ type: String.Type) throws -> String {
        guard case .string(let value) = try getNextValue() else {
            throw FirestoreDecodingError.typeMismatch(expected: "string", actual: values[currentIndex - 1])
        }
        return value
    }

    mutating func decode(_ type: Double.Type) throws -> Double {
        let value = try getNextValue()
        switch value {
        case .double(let d): return d
        case .integer(let i): return Double(i)
        default:
            throw FirestoreDecodingError.typeMismatch(expected: "double", actual: value)
        }
    }

    mutating func decode(_ type: Float.Type) throws -> Float {
        Float(try decode(Double.self))
    }

    mutating func decode(_ type: Int.Type) throws -> Int {
        Int(try decode(Int64.self))
    }

    mutating func decode(_ type: Int8.Type) throws -> Int8 {
        Int8(try decode(Int64.self))
    }

    mutating func decode(_ type: Int16.Type) throws -> Int16 {
        Int16(try decode(Int64.self))
    }

    mutating func decode(_ type: Int32.Type) throws -> Int32 {
        Int32(try decode(Int64.self))
    }

    mutating func decode(_ type: Int64.Type) throws -> Int64 {
        guard case .integer(let value) = try getNextValue() else {
            throw FirestoreDecodingError.typeMismatch(expected: "integer", actual: values[currentIndex - 1])
        }
        return value
    }

    mutating func decode(_ type: UInt.Type) throws -> UInt {
        UInt(try decode(Int64.self))
    }

    mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
        UInt8(try decode(Int64.self))
    }

    mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
        UInt16(try decode(Int64.self))
    }

    mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
        UInt32(try decode(Int64.self))
    }

    mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
        UInt64(try decode(Int64.self))
    }

    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let value = try getNextValue()

        if type == Date.self {
            guard case .timestamp(let date) = value else {
                throw FirestoreDecodingError.typeMismatch(expected: "timestamp", actual: value)
            }
            return date as! T
        }

        if type == Data.self {
            guard case .bytes(let data) = value else {
                throw FirestoreDecodingError.typeMismatch(expected: "bytes", actual: value)
            }
            return data as! T
        }

        let decoder = _FirestoreDecoder(value: value, keyDecodingStrategy: keyDecodingStrategy)
        return try T(from: decoder)
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy type: NestedKey.Type
    ) throws -> KeyedDecodingContainer<NestedKey> {
        guard case .map(let fields) = try getNextValue() else {
            throw FirestoreDecodingError.typeMismatch(expected: "map", actual: values[currentIndex - 1])
        }
        return KeyedDecodingContainer(
            FirestoreKeyedDecodingContainer<NestedKey>(
                fields: fields,
                codingPath: codingPath,
                keyDecodingStrategy: keyDecodingStrategy
            )
        )
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard case .array(let nestedValues) = try getNextValue() else {
            throw FirestoreDecodingError.typeMismatch(expected: "array", actual: values[currentIndex - 1])
        }
        return FirestoreUnkeyedDecodingContainer(
            values: nestedValues,
            codingPath: codingPath,
            keyDecodingStrategy: keyDecodingStrategy
        )
    }

    mutating func superDecoder() throws -> Decoder {
        _FirestoreDecoder(value: try getNextValue(), keyDecodingStrategy: keyDecodingStrategy)
    }

    private mutating func getNextValue() throws -> FirestoreValue {
        guard !isAtEnd else {
            throw FirestoreDecodingError.outOfBounds(currentIndex)
        }
        let value = values[currentIndex]
        currentIndex += 1
        return value
    }
}

// MARK: - Single Value Container

private struct FirestoreSingleValueDecodingContainer: SingleValueDecodingContainer {
    var codingPath: [CodingKey]
    let value: FirestoreValue
    let keyDecodingStrategy: KeyDecodingStrategy

    func decodeNil() -> Bool {
        if case .null = value { return true }
        return false
    }

    func decode(_ type: Bool.Type) throws -> Bool {
        guard case .boolean(let v) = value else {
            throw FirestoreDecodingError.typeMismatch(expected: "boolean", actual: value)
        }
        return v
    }

    func decode(_ type: String.Type) throws -> String {
        guard case .string(let v) = value else {
            throw FirestoreDecodingError.typeMismatch(expected: "string", actual: value)
        }
        return v
    }

    func decode(_ type: Double.Type) throws -> Double {
        switch value {
        case .double(let d): return d
        case .integer(let i): return Double(i)
        default:
            throw FirestoreDecodingError.typeMismatch(expected: "double", actual: value)
        }
    }

    func decode(_ type: Float.Type) throws -> Float {
        Float(try decode(Double.self))
    }

    func decode(_ type: Int.Type) throws -> Int {
        Int(try decode(Int64.self))
    }

    func decode(_ type: Int8.Type) throws -> Int8 {
        Int8(try decode(Int64.self))
    }

    func decode(_ type: Int16.Type) throws -> Int16 {
        Int16(try decode(Int64.self))
    }

    func decode(_ type: Int32.Type) throws -> Int32 {
        Int32(try decode(Int64.self))
    }

    func decode(_ type: Int64.Type) throws -> Int64 {
        guard case .integer(let v) = value else {
            throw FirestoreDecodingError.typeMismatch(expected: "integer", actual: value)
        }
        return v
    }

    func decode(_ type: UInt.Type) throws -> UInt {
        UInt(try decode(Int64.self))
    }

    func decode(_ type: UInt8.Type) throws -> UInt8 {
        UInt8(try decode(Int64.self))
    }

    func decode(_ type: UInt16.Type) throws -> UInt16 {
        UInt16(try decode(Int64.self))
    }

    func decode(_ type: UInt32.Type) throws -> UInt32 {
        UInt32(try decode(Int64.self))
    }

    func decode(_ type: UInt64.Type) throws -> UInt64 {
        UInt64(try decode(Int64.self))
    }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        if type == Date.self {
            guard case .timestamp(let date) = value else {
                throw FirestoreDecodingError.typeMismatch(expected: "timestamp", actual: value)
            }
            return date as! T
        }

        if type == Data.self {
            guard case .bytes(let data) = value else {
                throw FirestoreDecodingError.typeMismatch(expected: "bytes", actual: value)
            }
            return data as! T
        }

        let decoder = _FirestoreDecoder(value: value, keyDecodingStrategy: keyDecodingStrategy)
        return try T(from: decoder)
    }
}

// MARK: - Error

/// A value that could not be decoded from Firestore.
public enum FirestoreDecodingError: Error, Sendable {
    case keyNotFound(String)
    case typeMismatch(expected: String, actual: FirestoreValue)
    case outOfBounds(Int)
}

extension FirestoreDecodingError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .keyNotFound(let key):
            return "Key not found: \(key)"
        case .typeMismatch(let expected, let actual):
            return "Type mismatch: expected \(expected), got \(actual)"
        case .outOfBounds(let index):
            return "Array index out of bounds: \(index)"
        }
    }
}
