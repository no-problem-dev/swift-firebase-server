import Foundation

/// Cloud Storageオブジェクトのメタデータ
public struct StorageObject: Sendable, Codable {
    /// オブジェクトID
    public let id: String

    /// オブジェクト名（パス）
    public let name: String

    /// バケット名
    public let bucket: String

    /// コンテンツタイプ
    public let contentType: String?

    /// ファイルサイズ（バイト）
    public let size: Int64

    /// MD5ハッシュ（Base64エンコード）
    public let md5Hash: String?

    /// 作成日時
    public let timeCreated: Date?

    /// 更新日時
    public let updated: Date?

    /// メディアリンク（ダウンロードURL）
    public let mediaLink: String?

    public init(
        id: String,
        name: String,
        bucket: String,
        contentType: String?,
        size: Int64,
        md5Hash: String? = nil,
        timeCreated: Date? = nil,
        updated: Date? = nil,
        mediaLink: String? = nil
    ) {
        self.id = id
        self.name = name
        self.bucket = bucket
        self.contentType = contentType
        self.size = size
        self.md5Hash = md5Hash
        self.timeCreated = timeCreated
        self.updated = updated
        self.mediaLink = mediaLink
    }
}

// MARK: - JSON Parsing

extension StorageObject {
    /// REST APIレスポンスからStorageObjectを生成
    static func fromJSON(_ json: [String: Any]) -> StorageObject? {
        guard
            let id = json["id"] as? String,
            let name = json["name"] as? String,
            let bucket = json["bucket"] as? String
        else {
            return nil
        }

        let size: Int64
        if let sizeString = json["size"] as? String {
            size = Int64(sizeString) ?? 0
        } else if let sizeInt = json["size"] as? Int64 {
            size = sizeInt
        } else {
            size = 0
        }

        let timeCreated = (json["timeCreated"] as? String).flatMap { parseISO8601Date($0) }
        let updated = (json["updated"] as? String).flatMap { parseISO8601Date($0) }

        return StorageObject(
            id: id,
            name: name,
            bucket: bucket,
            contentType: json["contentType"] as? String,
            size: size,
            md5Hash: json["md5Hash"] as? String,
            timeCreated: timeCreated,
            updated: updated,
            mediaLink: json["mediaLink"] as? String
        )
    }

    private static func parseISO8601Date(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }
}
