import Foundation

/// Swift型をFirestoreValue/Documentに変換するエンコーダー
///
/// Codableな型をFirestore REST APIで使用可能な形式に変換する。
///
/// 使用例:
/// ```swift
/// struct User: Codable {
///     let name: String
///     let age: Int
/// }
///
/// let encoder = FirestoreEncoder()
/// let fields = try encoder.encode(User(name: "Alice", age: 30))
/// // ["name": .string("Alice"), "age": .integer(30)]
///
/// // snake_case変換を使用する場合
/// let snakeCaseEncoder = FirestoreEncoder(keyEncodingStrategy: .convertToSnakeCase)
/// let fields = try snakeCaseEncoder.encode(User(name: "Alice", age: 30))
/// // ["name": .string("Alice"), "age": .integer(30)]
///
/// struct UserProfile: Codable {
///     let userId: String
///     let displayName: String
/// }
/// let profileFields = try snakeCaseEncoder.encode(UserProfile(userId: "123", displayName: "Alice"))
/// // ["user_id": .string("123"), "display_name": .string("Alice")]
/// ```
public struct FirestoreEncoder: Sendable {
    /// キーのエンコーディング戦略
    public let keyEncodingStrategy: KeyEncodingStrategy

    /// イニシャライザ
    /// - Parameter keyEncodingStrategy: キーのエンコーディング戦略（デフォルト: .useDefaultKeys）
    public init(keyEncodingStrategy: KeyEncodingStrategy = .useDefaultKeys) {
        self.keyEncodingStrategy = keyEncodingStrategy
    }

    /// Encodableな値をFirestoreフィールドマップに変換
    /// - Parameter value: エンコードする値
    /// - Returns: フィールド名とFirestoreValueのマップ
    public func encode<T: Encodable>(_ value: T) throws -> [String: FirestoreValue] {
        let encoder = _FirestoreEncoder(keyEncodingStrategy: keyEncodingStrategy)
        try value.encode(to: encoder)

        guard case .map(let fields) = encoder.value else {
            throw FirestoreEncodingError.topLevelNotObject
        }
        return fields
    }

    /// Encodableな値を単一のFirestoreValueに変換
    /// - Parameter value: エンコードする値
    /// - Returns: FirestoreValue
    public func encodeValue<T: Encodable>(_ value: T) throws -> FirestoreValue {
        let encoder = _FirestoreEncoder(keyEncodingStrategy: keyEncodingStrategy)
        try value.encode(to: encoder)
        return encoder.value
    }
}

// MARK: - Internal Encoder Implementation

private final class _FirestoreEncoder: Encoder {
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]
    var value: FirestoreValue = .null
    let keyEncodingStrategy: KeyEncodingStrategy

    init(keyEncodingStrategy: KeyEncodingStrategy = .useDefaultKeys) {
        self.keyEncodingStrategy = keyEncodingStrategy
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        let container = FirestoreKeyedEncodingContainer<Key>(
            encoder: self,
            keyEncodingStrategy: keyEncodingStrategy
        )
        return KeyedEncodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        FirestoreUnkeyedEncodingContainer(encoder: self, keyEncodingStrategy: keyEncodingStrategy)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        FirestoreSingleValueEncodingContainer(encoder: self, keyEncodingStrategy: keyEncodingStrategy)
    }
}

// MARK: - Keyed Container

private struct FirestoreKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    var codingPath: [CodingKey] = []
    let encoder: _FirestoreEncoder
    let keyEncodingStrategy: KeyEncodingStrategy
    var fields: [String: FirestoreValue] = [:]

    init(encoder: _FirestoreEncoder, keyEncodingStrategy: KeyEncodingStrategy) {
        self.encoder = encoder
        self.keyEncodingStrategy = keyEncodingStrategy
        encoder.value = .map([:])
    }

    mutating func encodeNil(forKey key: Key) throws {
        setField(key, .null)
    }

    mutating func encode(_ value: Bool, forKey key: Key) throws {
        setField(key, .boolean(value))
    }

    mutating func encode(_ value: String, forKey key: Key) throws {
        setField(key, .string(value))
    }

    mutating func encode(_ value: Double, forKey key: Key) throws {
        setField(key, .double(value))
    }

    mutating func encode(_ value: Float, forKey key: Key) throws {
        setField(key, .double(Double(value)))
    }

    mutating func encode(_ value: Int, forKey key: Key) throws {
        setField(key, .integer(Int64(value)))
    }

    mutating func encode(_ value: Int8, forKey key: Key) throws {
        setField(key, .integer(Int64(value)))
    }

    mutating func encode(_ value: Int16, forKey key: Key) throws {
        setField(key, .integer(Int64(value)))
    }

    mutating func encode(_ value: Int32, forKey key: Key) throws {
        setField(key, .integer(Int64(value)))
    }

    mutating func encode(_ value: Int64, forKey key: Key) throws {
        setField(key, .integer(value))
    }

    mutating func encode(_ value: UInt, forKey key: Key) throws {
        setField(key, .integer(Int64(value)))
    }

    mutating func encode(_ value: UInt8, forKey key: Key) throws {
        setField(key, .integer(Int64(value)))
    }

    mutating func encode(_ value: UInt16, forKey key: Key) throws {
        setField(key, .integer(Int64(value)))
    }

    mutating func encode(_ value: UInt32, forKey key: Key) throws {
        setField(key, .integer(Int64(value)))
    }

    mutating func encode(_ value: UInt64, forKey key: Key) throws {
        setField(key, .integer(Int64(value)))
    }

    mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        // 特殊な型のハンドリング
        if let date = value as? Date {
            setField(key, .timestamp(date))
            return
        }
        if let data = value as? Data {
            setField(key, .bytes(data))
            return
        }

        // 一般的なEncodable
        let nestedEncoder = _FirestoreEncoder(keyEncodingStrategy: keyEncodingStrategy)
        try value.encode(to: nestedEncoder)
        setField(key, nestedEncoder.value)
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type,
        forKey key: Key
    ) -> KeyedEncodingContainer<NestedKey> {
        let nestedEncoder = _FirestoreEncoder(keyEncodingStrategy: keyEncodingStrategy)
        let container = FirestoreKeyedEncodingContainer<NestedKey>(
            encoder: nestedEncoder,
            keyEncodingStrategy: keyEncodingStrategy
        )
        // Note: 値は後で設定される
        return KeyedEncodingContainer(container)
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let nestedEncoder = _FirestoreEncoder(keyEncodingStrategy: keyEncodingStrategy)
        return FirestoreUnkeyedEncodingContainer(encoder: nestedEncoder, keyEncodingStrategy: keyEncodingStrategy)
    }

    mutating func superEncoder() -> Encoder {
        encoder
    }

    mutating func superEncoder(forKey key: Key) -> Encoder {
        encoder
    }

    private mutating func setField(_ key: Key, _ value: FirestoreValue) {
        if case .map(var existingFields) = encoder.value {
            let encodedKey = keyEncodingStrategy.encode(key.stringValue)
            existingFields[encodedKey] = value
            encoder.value = .map(existingFields)
        }
    }
}

// MARK: - Unkeyed Container

private struct FirestoreUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    var codingPath: [CodingKey] = []
    var count: Int = 0
    let encoder: _FirestoreEncoder
    let keyEncodingStrategy: KeyEncodingStrategy
    var values: [FirestoreValue] = []

    init(encoder: _FirestoreEncoder, keyEncodingStrategy: KeyEncodingStrategy) {
        self.encoder = encoder
        self.keyEncodingStrategy = keyEncodingStrategy
        encoder.value = .array([])
    }

    mutating func encodeNil() throws {
        append(.null)
    }

    mutating func encode(_ value: Bool) throws {
        append(.boolean(value))
    }

    mutating func encode(_ value: String) throws {
        append(.string(value))
    }

    mutating func encode(_ value: Double) throws {
        append(.double(value))
    }

    mutating func encode(_ value: Float) throws {
        append(.double(Double(value)))
    }

    mutating func encode(_ value: Int) throws {
        append(.integer(Int64(value)))
    }

    mutating func encode(_ value: Int8) throws {
        append(.integer(Int64(value)))
    }

    mutating func encode(_ value: Int16) throws {
        append(.integer(Int64(value)))
    }

    mutating func encode(_ value: Int32) throws {
        append(.integer(Int64(value)))
    }

    mutating func encode(_ value: Int64) throws {
        append(.integer(value))
    }

    mutating func encode(_ value: UInt) throws {
        append(.integer(Int64(value)))
    }

    mutating func encode(_ value: UInt8) throws {
        append(.integer(Int64(value)))
    }

    mutating func encode(_ value: UInt16) throws {
        append(.integer(Int64(value)))
    }

    mutating func encode(_ value: UInt32) throws {
        append(.integer(Int64(value)))
    }

    mutating func encode(_ value: UInt64) throws {
        append(.integer(Int64(value)))
    }

    mutating func encode<T: Encodable>(_ value: T) throws {
        if let date = value as? Date {
            append(.timestamp(date))
            return
        }
        if let data = value as? Data {
            append(.bytes(data))
            return
        }

        let nestedEncoder = _FirestoreEncoder(keyEncodingStrategy: keyEncodingStrategy)
        try value.encode(to: nestedEncoder)
        append(nestedEncoder.value)
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type
    ) -> KeyedEncodingContainer<NestedKey> {
        let nestedEncoder = _FirestoreEncoder(keyEncodingStrategy: keyEncodingStrategy)
        return KeyedEncodingContainer(FirestoreKeyedEncodingContainer<NestedKey>(
            encoder: nestedEncoder,
            keyEncodingStrategy: keyEncodingStrategy
        ))
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let nestedEncoder = _FirestoreEncoder(keyEncodingStrategy: keyEncodingStrategy)
        return FirestoreUnkeyedEncodingContainer(encoder: nestedEncoder, keyEncodingStrategy: keyEncodingStrategy)
    }

    mutating func superEncoder() -> Encoder {
        encoder
    }

    private mutating func append(_ value: FirestoreValue) {
        if case .array(var existingValues) = encoder.value {
            existingValues.append(value)
            encoder.value = .array(existingValues)
            count += 1
        }
    }
}

// MARK: - Single Value Container

private struct FirestoreSingleValueEncodingContainer: SingleValueEncodingContainer {
    var codingPath: [CodingKey] = []
    let encoder: _FirestoreEncoder
    let keyEncodingStrategy: KeyEncodingStrategy

    mutating func encodeNil() throws {
        encoder.value = .null
    }

    mutating func encode(_ value: Bool) throws {
        encoder.value = .boolean(value)
    }

    mutating func encode(_ value: String) throws {
        encoder.value = .string(value)
    }

    mutating func encode(_ value: Double) throws {
        encoder.value = .double(value)
    }

    mutating func encode(_ value: Float) throws {
        encoder.value = .double(Double(value))
    }

    mutating func encode(_ value: Int) throws {
        encoder.value = .integer(Int64(value))
    }

    mutating func encode(_ value: Int8) throws {
        encoder.value = .integer(Int64(value))
    }

    mutating func encode(_ value: Int16) throws {
        encoder.value = .integer(Int64(value))
    }

    mutating func encode(_ value: Int32) throws {
        encoder.value = .integer(Int64(value))
    }

    mutating func encode(_ value: Int64) throws {
        encoder.value = .integer(value)
    }

    mutating func encode(_ value: UInt) throws {
        encoder.value = .integer(Int64(value))
    }

    mutating func encode(_ value: UInt8) throws {
        encoder.value = .integer(Int64(value))
    }

    mutating func encode(_ value: UInt16) throws {
        encoder.value = .integer(Int64(value))
    }

    mutating func encode(_ value: UInt32) throws {
        encoder.value = .integer(Int64(value))
    }

    mutating func encode(_ value: UInt64) throws {
        encoder.value = .integer(Int64(value))
    }

    mutating func encode<T: Encodable>(_ value: T) throws {
        if let date = value as? Date {
            encoder.value = .timestamp(date)
            return
        }
        if let data = value as? Data {
            encoder.value = .bytes(data)
            return
        }

        let nestedEncoder = _FirestoreEncoder(keyEncodingStrategy: keyEncodingStrategy)
        try value.encode(to: nestedEncoder)
        encoder.value = nestedEncoder.value
    }
}

// MARK: - Error

/// エンコーディングエラー
enum FirestoreEncodingError: Error, Sendable {
    case topLevelNotObject
    case unsupportedType(Any.Type)
}

extension FirestoreEncodingError: CustomStringConvertible {
    var description: String {
        switch self {
        case .topLevelNotObject:
            return "Top-level value must encode to an object (map)"
        case .unsupportedType(let type):
            return "Unsupported type for Firestore encoding: \(type)"
        }
    }
}
