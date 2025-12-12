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

    // MARK: - Key Strategy Tests

    @Test("String.convertToSnakeCase - simple camelCase")
    func stringConvertToSnakeCaseSimple() {
        #expect("userId".convertToSnakeCase() == "user_id")
        #expect("displayName".convertToSnakeCase() == "display_name")
        #expect("createdAt".convertToSnakeCase() == "created_at")
        #expect("isActive".convertToSnakeCase() == "is_active")
    }

    @Test("String.convertToSnakeCase - with consecutive uppercase")
    func stringConvertToSnakeCaseConsecutive() {
        #expect("URLString".convertToSnakeCase() == "url_string")
        #expect("isHTTPSEnabled".convertToSnakeCase() == "is_https_enabled")
        #expect("httpMethod".convertToSnakeCase() == "http_method")
    }

    @Test("String.convertToSnakeCase - edge cases")
    func stringConvertToSnakeCaseEdgeCases() {
        #expect("name".convertToSnakeCase() == "name")
        #expect("Name".convertToSnakeCase() == "name")
        #expect("".convertToSnakeCase() == "")
        #expect("already_snake".convertToSnakeCase() == "already_snake")
    }

    @Test("String.convertFromSnakeCase - simple snake_case")
    func stringConvertFromSnakeCaseSimple() {
        #expect("user_id".convertFromSnakeCase() == "userId")
        #expect("display_name".convertFromSnakeCase() == "displayName")
        #expect("created_at".convertFromSnakeCase() == "createdAt")
        #expect("is_active".convertFromSnakeCase() == "isActive")
    }

    @Test("String.convertFromSnakeCase - edge cases")
    func stringConvertFromSnakeCaseEdgeCases() {
        #expect("name".convertFromSnakeCase() == "name")
        #expect("".convertFromSnakeCase() == "")
        #expect("alreadyCamelCase".convertFromSnakeCase() == "alreadyCamelCase")
    }

    @Test("FirestoreEncoder - snake_case key encoding")
    func encoderSnakeCaseKeyEncoding() throws {
        struct UserProfile: Codable {
            let userId: String
            let displayName: String
            let createdAt: Date
        }

        let testDate = Date(timeIntervalSince1970: 1704067200)
        let encoder = FirestoreEncoder(keyEncodingStrategy: .convertToSnakeCase)
        let fields = try encoder.encode(UserProfile(
            userId: "abc123",
            displayName: "Alice",
            createdAt: testDate
        ))

        #expect(fields["user_id"] == .string("abc123"))
        #expect(fields["display_name"] == .string("Alice"))
        #expect(fields["created_at"] == .timestamp(testDate))
        // Ensure camelCase keys are NOT present
        #expect(fields["userId"] == nil)
        #expect(fields["displayName"] == nil)
        #expect(fields["createdAt"] == nil)
    }

    @Test("FirestoreDecoder - snake_case key decoding")
    func decoderSnakeCaseKeyDecoding() throws {
        struct UserProfile: Codable, Equatable {
            let userId: String
            let displayName: String
            let profileImageId: String?
        }

        let fields: [String: FirestoreValue] = [
            "user_id": .string("abc123"),
            "display_name": .string("Alice"),
            "profile_image_id": .string("img456"),
        ]

        let decoder = FirestoreDecoder(keyDecodingStrategy: .convertFromSnakeCase)
        let profile = try decoder.decode(UserProfile.self, from: fields)

        #expect(profile.userId == "abc123")
        #expect(profile.displayName == "Alice")
        #expect(profile.profileImageId == "img456")
    }

    @Test("Round-trip with snake_case strategy")
    func roundTripSnakeCase() throws {
        struct UserProfile: Codable, Equatable {
            let userId: String
            let displayName: String
            let readingStreak: Int
            let isActive: Bool
        }

        let original = UserProfile(
            userId: "abc123",
            displayName: "Alice",
            readingStreak: 7,
            isActive: true
        )

        let encoder = FirestoreEncoder(keyEncodingStrategy: .convertToSnakeCase)
        let fields = try encoder.encode(original)

        // Verify snake_case keys
        #expect(fields["user_id"] != nil)
        #expect(fields["display_name"] != nil)
        #expect(fields["reading_streak"] != nil)
        #expect(fields["is_active"] != nil)

        let decoder = FirestoreDecoder(keyDecodingStrategy: .convertFromSnakeCase)
        let decoded = try decoder.decode(UserProfile.self, from: fields)

        #expect(original == decoded)
    }

    @Test("FirestoreEncoder - nested struct with snake_case")
    func encoderNestedSnakeCase() throws {
        struct Address: Codable {
            let streetName: String
            let postalCode: String
        }
        struct User: Codable {
            let userName: String
            let homeAddress: Address
        }

        let encoder = FirestoreEncoder(keyEncodingStrategy: .convertToSnakeCase)
        let fields = try encoder.encode(User(
            userName: "Alice",
            homeAddress: Address(streetName: "Main St", postalCode: "12345")
        ))

        #expect(fields["user_name"] == .string("Alice"))
        if case .map(let addressFields) = fields["home_address"] {
            #expect(addressFields["street_name"] == .string("Main St"))
            #expect(addressFields["postal_code"] == .string("12345"))
        } else {
            Issue.record("Expected map for home_address")
        }
    }

    @Test("FirestoreDecoder - nested struct with snake_case")
    func decoderNestedSnakeCase() throws {
        struct Address: Codable, Equatable {
            let streetName: String
            let postalCode: String
        }
        struct User: Codable, Equatable {
            let userName: String
            let homeAddress: Address
        }

        let fields: [String: FirestoreValue] = [
            "user_name": .string("Alice"),
            "home_address": .map([
                "street_name": .string("Main St"),
                "postal_code": .string("12345"),
            ]),
        ]

        let decoder = FirestoreDecoder(keyDecodingStrategy: .convertFromSnakeCase)
        let user = try decoder.decode(User.self, from: fields)

        #expect(user.userName == "Alice")
        #expect(user.homeAddress.streetName == "Main St")
        #expect(user.homeAddress.postalCode == "12345")
    }

    @Test("FirestoreEncoder - array with snake_case")
    func encoderArraySnakeCase() throws {
        struct Container: Codable {
            let itemList: [Item]
        }
        struct Item: Codable {
            let itemName: String
            let itemPrice: Int
        }

        let encoder = FirestoreEncoder(keyEncodingStrategy: .convertToSnakeCase)
        let fields = try encoder.encode(Container(itemList: [
            Item(itemName: "Book", itemPrice: 1000),
            Item(itemName: "Pen", itemPrice: 200),
        ]))

        if case .array(let items) = fields["item_list"] {
            #expect(items.count == 2)
            if case .map(let item1) = items[0] {
                #expect(item1["item_name"] == .string("Book"))
                #expect(item1["item_price"] == .integer(1000))
            } else {
                Issue.record("Expected map for item")
            }
        } else {
            Issue.record("Expected array for item_list")
        }
    }

    @Test("FirestoreDecoder - array with snake_case")
    func decoderArraySnakeCase() throws {
        struct Container: Codable, Equatable {
            let itemList: [Item]
        }
        struct Item: Codable, Equatable {
            let itemName: String
            let itemPrice: Int
        }

        let fields: [String: FirestoreValue] = [
            "item_list": .array([
                .map(["item_name": .string("Book"), "item_price": .integer(1000)]),
                .map(["item_name": .string("Pen"), "item_price": .integer(200)]),
            ]),
        ]

        let decoder = FirestoreDecoder(keyDecodingStrategy: .convertFromSnakeCase)
        let container = try decoder.decode(Container.self, from: fields)

        #expect(container.itemList.count == 2)
        #expect(container.itemList[0].itemName == "Book")
        #expect(container.itemList[0].itemPrice == 1000)
        #expect(container.itemList[1].itemName == "Pen")
        #expect(container.itemList[1].itemPrice == 200)
    }

    @Test("KeyEncodingStrategy - custom transformation")
    func keyEncodingStrategyCustom() throws {
        struct User: Codable {
            let name: String
            let age: Int
        }

        let encoder = FirestoreEncoder(keyEncodingStrategy: .custom { key in
            "prefix_\(key)"
        })
        let fields = try encoder.encode(User(name: "Alice", age: 30))

        #expect(fields["prefix_name"] == .string("Alice"))
        #expect(fields["prefix_age"] == .integer(30))
    }

    @Test("KeyDecodingStrategy - custom transformation")
    func keyDecodingStrategyCustom() throws {
        struct User: Codable, Equatable {
            let name: String
            let age: Int
        }

        let fields: [String: FirestoreValue] = [
            "prefix_name": .string("Alice"),
            "prefix_age": .integer(30),
        ]

        let decoder = FirestoreDecoder(keyDecodingStrategy: .custom { key in
            if key.hasPrefix("prefix_") {
                return String(key.dropFirst(7))
            }
            return key
        })
        let user = try decoder.decode(User.self, from: fields)

        #expect(user.name == "Alice")
        #expect(user.age == 30)
    }
}
