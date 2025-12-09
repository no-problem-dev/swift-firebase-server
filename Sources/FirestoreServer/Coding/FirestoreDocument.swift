import Foundation

/// Firestoreドキュメントの表現
///
/// REST APIのDocumentレスポンスに対応:
/// ```json
/// {
///   "name": "projects/.../documents/users/abc",
///   "fields": { ... },
///   "createTime": "2024-01-01T00:00:00Z",
///   "updateTime": "2024-01-01T00:00:00Z"
/// }
/// ```
public struct FirestoreDocument: Sendable {
    /// ドキュメントの完全なリソース名
    /// 例: `projects/my-project/databases/(default)/documents/users/abc`
    public let name: String

    /// ドキュメントのフィールド
    public let fields: [String: FirestoreValue]

    /// 作成日時
    public let createTime: Date?

    /// 更新日時
    public let updateTime: Date?

    /// 初期化
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

    /// ドキュメントパス部分を抽出
    /// 例: `users/abc`
    public var documentPath: String? {
        // "projects/.../documents/" の後ろを取得
        guard let range = name.range(of: "/documents/") else { return nil }
        return String(name[range.upperBound...])
    }

    /// ドキュメントIDを抽出
    public var documentId: String? {
        name.split(separator: "/").last.map(String.init)
    }
}

// MARK: - JSON Parsing

extension FirestoreDocument {
    /// REST APIのJSONレスポンスからパース
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

    /// 書き込み用のJSON辞書を生成（fieldsのみ）
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

/// FirestoreDocumentパースエラー
public enum FirestoreDocumentError: Error, Sendable {
    case missingName
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
