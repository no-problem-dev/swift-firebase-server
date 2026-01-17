import Foundation

/// Firestore ドキュメントイベントペイロード
///
/// Eventarc トリガー:
/// - `google.cloud.firestore.document.v1.created`
/// - `google.cloud.firestore.document.v1.updated`
/// - `google.cloud.firestore.document.v1.deleted`
/// - `google.cloud.firestore.document.v1.written`
///
/// Firestore ドキュメントの変更時に送信されるイベントです。
/// 新しい値（`value`）と古い値（`oldValue`）が含まれます。
///
/// ## 使用例
/// ```swift
/// server.webhook("webhooks", "firestore", "chat-created", body: FirestoreDocumentEvent.self) { request in
///     let event = request.body
///     if let message = event.value?.getString("message") {
///         print("New chat: \(message)")
///     }
///     return .ok
/// }
/// ```
public struct FirestoreDocumentEvent: Codable, Sendable {
    /// 変更後のドキュメント（削除の場合はnil）
    public let value: FirestoreDocument?

    /// 変更前のドキュメント（作成の場合はnil）
    public let oldValue: FirestoreDocument?

    /// 変更されたフィールドのマスク（更新の場合のみ）
    public let updateMask: UpdateMask?

    /// 更新マスク
    public struct UpdateMask: Codable, Sendable {
        /// 変更されたフィールドのパス
        public let fieldPaths: [String]?
    }
}

// MARK: - Firestore Document

/// Firestore ドキュメント
///
/// Firestoreの内部表現形式でのドキュメントデータです。
public struct FirestoreDocument: Codable, Sendable {
    /// ドキュメントのフルパス
    /// 例: `projects/my-project/databases/(default)/documents/users/abc123/books/xyz789`
    public let name: String?

    /// フィールド値（Firestore Value形式）
    public let fields: [String: FirestoreValue]?

    /// 作成日時
    public let createTime: String?

    /// 更新日時
    public let updateTime: String?

    /// ドキュメントIDを取得
    public var documentId: String? {
        guard let name = name else { return nil }
        return name.split(separator: "/").last.map(String.init)
    }

    /// フィールドから文字列値を取得
    public func getString(_ key: String) -> String? {
        fields?[key]?.stringValue
    }

    /// フィールドから整数値を取得
    public func getInt(_ key: String) -> Int? {
        guard let value = fields?[key]?.integerValue else { return nil }
        return Int(value)
    }

    /// フィールドからブール値を取得
    public func getBool(_ key: String) -> Bool? {
        fields?[key]?.booleanValue
    }

    /// フィールドからダブル値を取得
    public func getDouble(_ key: String) -> Double? {
        fields?[key]?.doubleValue
    }

    /// フィールドからタイムスタンプを取得
    public func getTimestamp(_ key: String) -> String? {
        fields?[key]?.timestampValue
    }

    /// フィールドからマップ（ネストしたオブジェクト）を取得
    public func getMap(_ key: String) -> [String: FirestoreValue]? {
        fields?[key]?.mapValue?.fields
    }

    /// フィールドから配列を取得
    public func getArray(_ key: String) -> [FirestoreValue]? {
        fields?[key]?.arrayValue?.values
    }
}

// MARK: - Firestore Value

/// Firestore 値の内部表現
///
/// Firestoreは型情報を含む特殊なJSON形式を使用します。
public struct FirestoreValue: Codable, Sendable {
    /// 文字列値
    public let stringValue: String?

    /// 整数値（文字列として表現）
    public let integerValue: String?

    /// ブール値
    public let booleanValue: Bool?

    /// ダブル値
    public let doubleValue: Double?

    /// タイムスタンプ値
    public let timestampValue: String?

    /// null値
    public let nullValue: String?

    /// マップ値
    public let mapValue: MapValue?

    /// 配列値
    public let arrayValue: ArrayValue?

    /// 参照値
    public let referenceValue: String?

    /// GeoPoint値
    public let geoPointValue: GeoPointValue?

    /// バイト値（Base64エンコード）
    public let bytesValue: String?

    /// マップ値
    public struct MapValue: Codable, Sendable {
        public let fields: [String: FirestoreValue]?
    }

    /// 配列値
    public struct ArrayValue: Codable, Sendable {
        public let values: [FirestoreValue]?
    }

    /// GeoPoint値
    public struct GeoPointValue: Codable, Sendable {
        public let latitude: Double?
        public let longitude: Double?
    }
}

// MARK: - Path Parameter Extraction

extension FirestoreDocumentEvent {
    /// ドキュメントパスからパラメータを抽出
    ///
    /// パスパターンに基づいてドキュメントパスからパラメータを抽出します。
    ///
    /// ## 使用例
    /// ```swift
    /// let event: FirestoreDocumentEvent = ...
    /// let params = event.extractPathParams(pattern: "users/{userId}/books/{bookId}/chats/{chatId}")
    /// // params = ["userId": "abc123", "bookId": "xyz789", "chatId": "chat001"]
    /// ```
    ///
    /// - Parameter pattern: パスパターン（`{param}` 形式のプレースホルダーを含む）
    /// - Returns: 抽出されたパラメータ辞書、失敗時はnil
    public func extractPathParams(pattern: String) -> [String: String]? {
        guard let name = value?.name ?? oldValue?.name else { return nil }

        // Firestoreのフルパスからドキュメントパス部分を抽出
        // 形式: projects/{project}/databases/(default)/documents/{path}
        guard let documentsIndex = name.range(of: "/documents/") else { return nil }
        let documentPath = String(name[documentsIndex.upperBound...])

        let patternParts = pattern.split(separator: "/")
        let pathParts = documentPath.split(separator: "/")

        guard patternParts.count == pathParts.count else { return nil }

        var params: [String: String] = [:]

        for (patternPart, pathPart) in zip(patternParts, pathParts) {
            let pattern = String(patternPart)
            let path = String(pathPart)

            if pattern.hasPrefix("{") && pattern.hasSuffix("}") {
                // パラメータプレースホルダー
                let paramName = String(pattern.dropFirst().dropLast())
                params[paramName] = path
            } else if pattern != path {
                // 固定パス部分が一致しない
                return nil
            }
        }

        return params
    }
}
