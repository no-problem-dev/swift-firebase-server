import Foundation
import Testing
@testable import FirestoreServer

@Suite("Coding Tests")
struct CodingTests {
    @Test("FirestoreValue - string to JSON")
    func valueStringToJSON() {
        let value = FirestoreValue.string("hello")
        let json = value.toJSON()
        #expect(json["stringValue"] as? String == "hello")
    }

    @Test("FirestoreValue - integer to JSON")
    func valueIntegerToJSON() {
        let value = FirestoreValue.integer(123)
        let json = value.toJSON()
        #expect(json["integerValue"] as? String == "123")
    }

    @Test("FirestoreValue - map to JSON")
    func valueMapToJSON() {
        let value = FirestoreValue.map([
            "name": .string("Alice"),
            "age": .integer(30),
        ])
        let json = value.toJSON()
        let mapValue = json["mapValue"] as? [String: Any]
        let fields = mapValue?["fields"] as? [String: Any]
        #expect(fields != nil)
    }

    @Test("FirestoreValue - parse string from JSON")
    func valueStringFromJSON() throws {
        let json: [String: Any] = ["stringValue": "hello"]
        let value = try FirestoreValue.fromJSON(json)
        #expect(value == .string("hello"))
    }

    @Test("FirestoreValue - parse integer from JSON")
    func valueIntegerFromJSON() throws {
        let json: [String: Any] = ["integerValue": "123"]
        let value = try FirestoreValue.fromJSON(json)
        #expect(value == .integer(123))
    }

    @Test("FirestoreEncoder - simple struct")
    func encoderSimpleStruct() throws {
        struct User: Codable {
            let name: String
            let age: Int
        }

        let encoder = FirestoreEncoder()
        let fields = try encoder.encode(User(name: "Alice", age: 30))

        #expect(fields["name"] == .string("Alice"))
        #expect(fields["age"] == .integer(30))
    }

    @Test("FirestoreEncoder - nested struct")
    func encoderNestedStruct() throws {
        struct Address: Codable {
            let city: String
        }
        struct User: Codable {
            let name: String
            let address: Address
        }

        let encoder = FirestoreEncoder()
        let fields = try encoder.encode(User(name: "Alice", address: Address(city: "Tokyo")))

        #expect(fields["name"] == .string("Alice"))
        if case .map(let addressFields) = fields["address"] {
            #expect(addressFields["city"] == .string("Tokyo"))
        } else {
            Issue.record("Expected map for address")
        }
    }

    @Test("FirestoreEncoder - array")
    func encoderArray() throws {
        struct User: Codable {
            let tags: [String]
        }

        let encoder = FirestoreEncoder()
        let fields = try encoder.encode(User(tags: ["swift", "vapor"]))

        if case .array(let values) = fields["tags"] {
            #expect(values.count == 2)
            #expect(values[0] == .string("swift"))
            #expect(values[1] == .string("vapor"))
        } else {
            Issue.record("Expected array for tags")
        }
    }

    @Test("FirestoreDecoder - simple struct")
    func decoderSimpleStruct() throws {
        struct User: Codable, Equatable {
            let name: String
            let age: Int
        }

        let fields: [String: FirestoreValue] = [
            "name": .string("Alice"),
            "age": .integer(30),
        ]

        let decoder = FirestoreDecoder()
        let user = try decoder.decode(User.self, from: fields)

        #expect(user.name == "Alice")
        #expect(user.age == 30)
    }

    @Test("FirestoreDecoder - with Date")
    func decoderWithDate() throws {
        struct Event: Codable {
            let title: String
            let date: Date
        }

        let testDate = Date(timeIntervalSince1970: 1704067200) // 2024-01-01 00:00:00 UTC
        let fields: [String: FirestoreValue] = [
            "title": .string("New Year"),
            "date": .timestamp(testDate),
        ]

        let decoder = FirestoreDecoder()
        let event = try decoder.decode(Event.self, from: fields)

        #expect(event.title == "New Year")
        #expect(event.date == testDate)
    }

    @Test("Round-trip encode/decode")
    func roundTrip() throws {
        struct Book: Codable, Equatable {
            let title: String
            let pageCount: Int
            let rating: Double
            let isPublished: Bool
        }

        let original = Book(title: "Swift Programming", pageCount: 500, rating: 4.5, isPublished: true)

        let encoder = FirestoreEncoder()
        let fields = try encoder.encode(original)

        let decoder = FirestoreDecoder()
        let decoded = try decoder.decode(Book.self, from: fields)

        #expect(original == decoded)
    }
}
