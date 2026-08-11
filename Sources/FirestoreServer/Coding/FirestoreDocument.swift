import Foundation

/// A document as the Firestore REST API returns it.
///
/// ```json
/// {
///   "name": "projects/.../documents/users/abc",
///   "fields": { ... },
///   "createTime": "2024-01-01T00:00:00Z",
///   "updateTime": "2024-01-01T00:00:00Z"
/// }
/// ```
public struct FirestoreDocument: Sendable {
    /// The full resource name, such as
    /// `projects/my-project/databases/(default)/documents/users/abc`.
    public let name: String

    public let fields: [String: FirestoreValue]

    /// When the server created the document, if the response carried it.
    public let createTime: Date?

    /// When the server last wrote the document, if the response carried it.
    ///
    /// This is the value to send back as a `currentDocument.updateTime` precondition to make a
    /// later write conditional on nothing else having changed the document in between.
    public let updateTime: Date?

    public init(
        name: String,
        fields: [String: FirestoreValue],
        createTime: Date? = nil,
        updateTime: Date? = nil
    ) {
        self.name = name
        self.fields = fields
        self.createTime = createTime
        self.updateTime = updateTime
    }

    /// The path relative to the database root, such as `users/abc`.
    ///
    /// Everything after `/documents/` is kept, so a document in a subcollection yields the
    /// whole chain (`users/abc/posts/1`). `nil` when the name has no `/documents/` segment.
    public var documentPath: String? {
        // Take whatever follows "projects/.../documents/"
        guard let range = name.range(of: "/documents/") else { return nil }
        return String(name[range.upperBound...])
    }

    /// The document's own ID, the last segment of its resource name.
    public var documentId: String? {
        name.split(separator: "/").last.map(String.init)
    }
}

// MARK: - JSON Parsing

extension FirestoreDocument {
    /// Reads a document out of a REST response.
    ///
    /// A response with no `fields` object decodes as a document with no fields, and a
    /// timestamp that cannot be parsed becomes `nil` rather than an error.
    ///
    /// - Throws: `FirestoreDocumentError.missingName` when the response carries no `name`.
    public static func fromJSON(_ json: [String: Any]) throws -> FirestoreDocument {
        guard let name = json["name"] as? String else {
            throw FirestoreDocumentError.missingName
        }

        var fields: [String: FirestoreValue] = [:]
        if let fieldsJSON = json["fields"] as? [String: [String: Any]] {
            for (key, value) in fieldsJSON {
                fields[key] = try FirestoreValue.fromJSON(value)
            }
        }

        let createTime: Date?
        if let createTimeStr = json["createTime"] as? String {
            createTime = parseTimestamp(createTimeStr)
        } else {
            createTime = nil
        }

        let updateTime: Date?
        if let updateTimeStr = json["updateTime"] as? String {
            updateTime = parseTimestamp(updateTimeStr)
        } else {
            updateTime = nil
        }

        return FirestoreDocument(
            name: name,
            fields: fields,
            createTime: createTime,
            updateTime: updateTime
        )
    }

    /// Renders the document as a write payload holding only its `fields`.
    ///
    /// `name`, `createTime`, and `updateTime` are left out: the server owns the timestamps, and
    /// a write addresses the document through its URL rather than through the body.
    public func toJSON() -> [String: Any] {
        var fieldsJSON: [String: Any] = [:]
        for (key, value) in fields {
            fieldsJSON[key] = value.toJSON()
        }
        return ["fields": fieldsJSON]
    }

    private static func parseTimestamp(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}

// MARK: - Error

/// A REST response that could not be read as a document.
public enum FirestoreDocumentError: Error, Sendable {
    case missingName

    /// Never thrown by `fromJSON(_:)`, which reads a response without `fields` as a document
    /// that has none.
    case missingFields
}

extension FirestoreDocumentError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .missingName:
            return "Document JSON is missing 'name' field"
        case .missingFields:
            return "Document JSON is missing 'fields' field"
        }
    }
}
