import Foundation

/// Encodes `Encodable` values into Firestore REST field values.
///
/// `Date` becomes a `timestampValue` and `Data` a `bytesValue`; every other type follows the
/// usual `Encodable` path, with integers becoming `integerValue`, floating-point values
/// `doubleValue`, nested structs `mapValue`, and arrays `arrayValue`.
///
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
/// // With snake_case conversion
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
    public let keyEncodingStrategy: KeyEncodingStrategy

    /// - Parameter keyEncodingStrategy: How property names become field names. Defaults to
    ///   writing them unchanged.
    public init(keyEncodingStrategy: KeyEncodingStrategy = .useDefaultKeys) {
        self.keyEncodingStrategy = keyEncodingStrategy
    }

    /// Encodes a value into the field map of a Firestore document.
    ///
    /// - Throws: `FirestoreEncodingError.topLevelNotObject` if the value does not encode to a
    ///   map — an array or a bare scalar has no field names and cannot be a document.
    public func encode<T: Encodable>(_ value: T) throws -> [String: FirestoreValue] {
        let encoder = _FirestoreEncoder(keyEncodingStrategy: keyEncodingStrategy)
        try value.encode(to: encoder)

        guard case .map(let fields) = encoder.value else {
            throw FirestoreEncodingError.topLevelNotObject
        }
        return fields
    }

    /// Encodes a value into a single field value, for anything that is not a whole document.
    ///
    /// Unlike `encode(_:)` this accepts scalars and arrays, which is what makes it usable for
    /// query operands and single-field updates.
    public func encodeValue<T: Encodable>(_ value: T) throws -> FirestoreValue {
        let encoder = _FirestoreEncoder(keyEncodingStrategy: keyEncodingStrategy)
        try value.encode(to: encoder)
        return encoder.value
    }
}

// MARK: - Internal Encoder Implementation

/// One position in the value being encoded, held by reference.
///
/// Containers hand out child nodes rather than copies of a value, so a nested container keeps
/// writing into the tree its parent will read: `nestedContainer(keyedBy:forKey:)`,
/// `nestedUnkeyedContainer(forKey:)`, and `superEncoder()` all land back under the key that
/// produced them instead of being dropped.
private final class EncodingNode {
    private enum Storage {
        case value(FirestoreValue)
        case map([String: EncodingNode])
        case array([EncodingNode])
    }

    private var storage: Storage = .value(.null)

    /// Overwrites this position with a leaf value.
    func write(_ value: FirestoreValue) {
        storage = .value(value)
    }

    /// Turns this position into a map, keeping any children already written into it.
    func startMap() {
        if case .map = storage { return }
        storage = .map([:])
    }

    /// Turns this position into an array, keeping any children already appended to it.
    func startArray() {
        if case .array = storage { return }
        storage = .array([])
    }

    /// Returns the child under `key`, creating it on first use.
    func child(forKey key: String) -> EncodingNode {
        startMap()
        guard case .map(var children) = storage else {
            preconditionFailure("startMap() left the node in a non-map state")
        }
        if let existing = children[key] {
            return existing
        }
        let child = EncodingNode()
        children[key] = child
        storage = .map(children)
        return child
    }

    /// Appends a new child to this array position and returns it.
    func appendChild() -> EncodingNode {
        startArray()
        guard case .array(var children) = storage else {
            preconditionFailure("startArray() left the node in a non-array state")
        }
        let child = EncodingNode()
        children.append(child)
        storage = .array(children)
        return child
    }

    /// How many children this position holds, which is the count an unkeyed container reports.
    var childCount: Int {
        switch storage {
        case .value:
            return 0
        case .map(let children):
            return children.count
        case .array(let children):
            return children.count
        }
    }

    /// The Firestore value this position and everything below it encodes to.
    var value: FirestoreValue {
        switch storage {
        case .value(let value):
            return value
        case .map(let children):
            return .map(children.mapValues(\.value))
        case .array(let children):
            return .array(children.map(\.value))
        }
    }
}

private final class _FirestoreEncoder: Encoder {
    let codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] = [:]
    let keyEncodingStrategy: KeyEncodingStrategy

    /// The position in the tree this encoder writes to.
    let node: EncodingNode

    init(
        keyEncodingStrategy: KeyEncodingStrategy = .useDefaultKeys,
        node: EncodingNode = EncodingNode(),
        codingPath: [CodingKey] = []
    ) {
        self.keyEncodingStrategy = keyEncodingStrategy
        self.node = node
        self.codingPath = codingPath
    }

    var value: FirestoreValue {
        node.value
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        let container = FirestoreKeyedEncodingContainer<Key>(
            node: node,
            keyEncodingStrategy: keyEncodingStrategy,
            codingPath: codingPath
        )
        return KeyedEncodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        FirestoreUnkeyedEncodingContainer(
            node: node,
            keyEncodingStrategy: keyEncodingStrategy,
            codingPath: codingPath
        )
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        FirestoreSingleValueEncodingContainer(
            node: node,
            keyEncodingStrategy: keyEncodingStrategy,
            codingPath: codingPath
        )
    }
}

// MARK: - Shared Encoding

/// Encodes one value into `node`, giving `Date` and `Data` their Firestore representations and
/// letting everything else re-enter the encoder.
private func encodeValue<T: Encodable>(
    _ value: T,
    into node: EncodingNode,
    keyEncodingStrategy: KeyEncodingStrategy,
    codingPath: [CodingKey]
) throws {
    if let date = value as? Date {
        node.write(.timestamp(date))
        return
    }
    if let data = value as? Data {
        node.write(.bytes(data))
        return
    }

    let nestedEncoder = _FirestoreEncoder(
        keyEncodingStrategy: keyEncodingStrategy,
        node: node,
        codingPath: codingPath
    )
    try value.encode(to: nestedEncoder)
}

// MARK: - Keyed Container

private struct FirestoreKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let codingPath: [CodingKey]
    let node: EncodingNode
    let keyEncodingStrategy: KeyEncodingStrategy

    init(node: EncodingNode, keyEncodingStrategy: KeyEncodingStrategy, codingPath: [CodingKey]) {
        self.node = node
        self.keyEncodingStrategy = keyEncodingStrategy
        self.codingPath = codingPath
        node.startMap()
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
        try encodeValue(
            value,
            into: child(for: key),
            keyEncodingStrategy: keyEncodingStrategy,
            codingPath: codingPath + [key]
        )
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type,
        forKey key: Key
    ) -> KeyedEncodingContainer<NestedKey> {
        KeyedEncodingContainer(FirestoreKeyedEncodingContainer<NestedKey>(
            node: child(for: key),
            keyEncodingStrategy: keyEncodingStrategy,
            codingPath: codingPath + [key]
        ))
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        FirestoreUnkeyedEncodingContainer(
            node: child(for: key),
            keyEncodingStrategy: keyEncodingStrategy,
            codingPath: codingPath + [key]
        )
    }

    mutating func superEncoder() -> Encoder {
        _FirestoreEncoder(
            keyEncodingStrategy: keyEncodingStrategy,
            node: node.child(forKey: "super"),
            codingPath: codingPath
        )
    }

    mutating func superEncoder(forKey key: Key) -> Encoder {
        _FirestoreEncoder(
            keyEncodingStrategy: keyEncodingStrategy,
            node: child(for: key),
            codingPath: codingPath + [key]
        )
    }

    private func child(for key: Key) -> EncodingNode {
        node.child(forKey: keyEncodingStrategy.encode(key.stringValue))
    }

    private func setField(_ key: Key, _ value: FirestoreValue) {
        child(for: key).write(value)
    }
}

// MARK: - Unkeyed Container

private struct FirestoreUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    let codingPath: [CodingKey]
    let node: EncodingNode
    let keyEncodingStrategy: KeyEncodingStrategy

    init(node: EncodingNode, keyEncodingStrategy: KeyEncodingStrategy, codingPath: [CodingKey]) {
        self.node = node
        self.keyEncodingStrategy = keyEncodingStrategy
        self.codingPath = codingPath
        node.startArray()
    }

    var count: Int {
        node.childCount
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
        try encodeValue(
            value,
            into: node.appendChild(),
            keyEncodingStrategy: keyEncodingStrategy,
            codingPath: codingPath + [FirestoreCodingKey(index: count)]
        )
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type
    ) -> KeyedEncodingContainer<NestedKey> {
        KeyedEncodingContainer(FirestoreKeyedEncodingContainer<NestedKey>(
            node: node.appendChild(),
            keyEncodingStrategy: keyEncodingStrategy,
            codingPath: codingPath + [FirestoreCodingKey(index: count)]
        ))
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        FirestoreUnkeyedEncodingContainer(
            node: node.appendChild(),
            keyEncodingStrategy: keyEncodingStrategy,
            codingPath: codingPath + [FirestoreCodingKey(index: count)]
        )
    }

    mutating func superEncoder() -> Encoder {
        _FirestoreEncoder(
            keyEncodingStrategy: keyEncodingStrategy,
            node: node.appendChild(),
            codingPath: codingPath + [FirestoreCodingKey(index: count)]
        )
    }

    private func append(_ value: FirestoreValue) {
        node.appendChild().write(value)
    }
}

// MARK: - Single Value Container

private struct FirestoreSingleValueEncodingContainer: SingleValueEncodingContainer {
    let codingPath: [CodingKey]
    let node: EncodingNode
    let keyEncodingStrategy: KeyEncodingStrategy

    init(node: EncodingNode, keyEncodingStrategy: KeyEncodingStrategy, codingPath: [CodingKey]) {
        self.node = node
        self.keyEncodingStrategy = keyEncodingStrategy
        self.codingPath = codingPath
    }

    mutating func encodeNil() throws {
        node.write(.null)
    }

    mutating func encode(_ value: Bool) throws {
        node.write(.boolean(value))
    }

    mutating func encode(_ value: String) throws {
        node.write(.string(value))
    }

    mutating func encode(_ value: Double) throws {
        node.write(.double(value))
    }

    mutating func encode(_ value: Float) throws {
        node.write(.double(Double(value)))
    }

    mutating func encode(_ value: Int) throws {
        node.write(.integer(Int64(value)))
    }

    mutating func encode(_ value: Int8) throws {
        node.write(.integer(Int64(value)))
    }

    mutating func encode(_ value: Int16) throws {
        node.write(.integer(Int64(value)))
    }

    mutating func encode(_ value: Int32) throws {
        node.write(.integer(Int64(value)))
    }

    mutating func encode(_ value: Int64) throws {
        node.write(.integer(value))
    }

    mutating func encode(_ value: UInt) throws {
        node.write(.integer(Int64(value)))
    }

    mutating func encode(_ value: UInt8) throws {
        node.write(.integer(Int64(value)))
    }

    mutating func encode(_ value: UInt16) throws {
        node.write(.integer(Int64(value)))
    }

    mutating func encode(_ value: UInt32) throws {
        node.write(.integer(Int64(value)))
    }

    mutating func encode(_ value: UInt64) throws {
        node.write(.integer(Int64(value)))
    }

    mutating func encode<T: Encodable>(_ value: T) throws {
        try encodeValue(
            value,
            into: node,
            keyEncodingStrategy: keyEncodingStrategy,
            codingPath: codingPath
        )
    }
}

// MARK: - Coding Key

/// The coding key an unkeyed container reports for its elements.
private struct FirestoreCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(index: Int) {
        self.stringValue = "Index \(index)"
        self.intValue = index
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.init(index: intValue)
    }
}

// MARK: - Error

/// A value that could not be encoded for Firestore.
public enum FirestoreEncodingError: Error, Sendable {
    /// The value did not encode to a map, so it has no field names and cannot be a document.
    case topLevelNotObject
}

extension FirestoreEncodingError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .topLevelNotObject:
            return "Top-level value must encode to an object (map)"
        }
    }
}
