import Foundation

/// FirestoreValue/DocumentからSwift型に変換するデコーダー
///
/// Firestore REST APIのレスポンスをCodableな型に変換する。
///
/// 使用例:
/// ```swift
/// struct User: Codable {
///     let name: String
///     let age: Int
/// }
///
/// let decoder = FirestoreDecoder()
/// let user: User = try decoder.decode(User.self, from: firestoreDocument)
/// ```
struct FirestoreDecoder: Sendable {
    init() {}

    /// FirestoreDocumentからDecodableな型に変換
    /// - Parameters:
    ///   - type: デコード先の型
    ///   - document: Firestoreドキュメント
    /// - Returns: デコードされた値
    func decode<T: Decodable>(_ type: T.Type, from document: FirestoreDocument) throws -> T {
        try decode(type, from: document.fields)
    }

    /// FirestoreValueのマップからDecodableな型に変換
    /// - Parameters:
    ///   - type: デコード先の型
    ///   - fields: フィールドマップ
    /// - Returns: デコードされた値
    func decode<T: Decodable>(_ type: T.Type, from fields: [String: FirestoreValue]) throws -> T {
        let decoder = _FirestoreDecoder(value: .map(fields))
        return try T(from: decoder)
    }

    /// 単一のFirestoreValueからDecodableな型に変換
    /// - Parameters:
    ///   - type: デコード先の型
    ///   - value: FirestoreValue
    /// - Returns: デコードされた値
    func decodeValue<T: Decodable>(_ type: T.Type, from value: FirestoreValue) throws -> T {
        let decoder = _FirestoreDecoder(value: value)
        return try T(from: decoder)
    }
}

// MARK: - Internal Decoder Implementation

private final class _FirestoreDecoder: Decoder {
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]
    let value: FirestoreValue

    init(value: FirestoreValue) {
        self.value = value
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard case .map(let fields) = value else {
            throw FirestoreDecodingError.typeMismatch(expected: "map", actual: value)
        }
        return KeyedDecodingContainer(FirestoreKeyedDecodingContainer<Key>(fields: fields, codingPath: codingPath))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard case .array(let values) = value else {
            throw FirestoreDecodingError.typeMismatch(expected: "array", actual: value)
        }
        return FirestoreUnkeyedDecodingContainer(values: values, codingPath: codingPath)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        FirestoreSingleValueDecodingContainer(codingPath: codingPath, value: value)
    }
}

// MARK: - Keyed Container

private struct FirestoreKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    var codingPath: [CodingKey]
    var allKeys: [Key] {
        fields.keys.compactMap { Key(stringValue: $0) }
    }

    let fields: [String: FirestoreValue]

    init(fields: [String: FirestoreValue], codingPath: [CodingKey]) {
        self.fields = fields
        self.codingPath = codingPath
    }

    func contains(_ key: Key) -> Bool {
        fields[key.stringValue] != nil
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        guard let value = fields[key.stringValue] else {
            return true
        }
        if case .null = value {
            return true
        }
        return false
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

        // 特殊な型のハンドリング
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

        // 一般的なDecodable
        let decoder = _FirestoreDecoder(value: value)
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
                codingPath: codingPath + [key]
            )
        )
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        guard case .array(let values) = try getValue(for: key) else {
            throw FirestoreDecodingError.typeMismatch(expected: "array", actual: try getValue(for: key))
        }
        return FirestoreUnkeyedDecodingContainer(values: values, codingPath: codingPath + [key])
    }

    func superDecoder() throws -> Decoder {
        _FirestoreDecoder(value: .map(fields))
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        _FirestoreDecoder(value: try getValue(for: key))
    }

    private func getValue(for key: Key) throws -> FirestoreValue {
        guard let value = fields[key.stringValue] else {
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

    init(values: [FirestoreValue], codingPath: [CodingKey]) {
        self.values = values
        self.codingPath = codingPath
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

        let decoder = _FirestoreDecoder(value: value)
        return try T(from: decoder)
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy type: NestedKey.Type
    ) throws -> KeyedDecodingContainer<NestedKey> {
        guard case .map(let fields) = try getNextValue() else {
            throw FirestoreDecodingError.typeMismatch(expected: "map", actual: values[currentIndex - 1])
        }
        return KeyedDecodingContainer(
            FirestoreKeyedDecodingContainer<NestedKey>(fields: fields, codingPath: codingPath)
        )
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard case .array(let nestedValues) = try getNextValue() else {
            throw FirestoreDecodingError.typeMismatch(expected: "array", actual: values[currentIndex - 1])
        }
        return FirestoreUnkeyedDecodingContainer(values: nestedValues, codingPath: codingPath)
    }

    mutating func superDecoder() throws -> Decoder {
        _FirestoreDecoder(value: try getNextValue())
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

        let decoder = _FirestoreDecoder(value: value)
        return try T(from: decoder)
    }
}

// MARK: - Error

/// デコーディングエラー
enum FirestoreDecodingError: Error, Sendable {
    case keyNotFound(String)
    case typeMismatch(expected: String, actual: FirestoreValue)
    case outOfBounds(Int)
}

extension FirestoreDecodingError: CustomStringConvertible {
    var description: String {
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
