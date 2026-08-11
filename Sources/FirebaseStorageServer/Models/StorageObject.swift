import Foundation

/// Metadata for one object in a bucket, as the Cloud Storage JSON API reports it.
///
/// A subset of the API's object resource — the fields an upload, a metadata fetch, or a listing
/// return. Every field except ``id``, ``name``, ``bucket``, and ``size`` degrades to `nil` when the
/// response omits it, so treat a missing value as "not reported", not as "absent on the object".
public struct StorageObject: Sendable, Codable {
    /// The object's fully qualified identity, normally `{bucket}/{name}#{generation}`.
    ///
    /// The emulator does not always send an `id`; in that case it is rebuilt from the generation,
    /// or falls back to `{bucket}/{name}` with no generation suffix at all. Do not parse it to
    /// recover the generation.
    public let id: String

    /// The object's full path inside the bucket, slashes included.
    ///
    /// Cloud Storage buckets are flat, so this is one string — `"images/user123.jpg"` — rather
    /// than a directory entry.
    public let name: String

    public let bucket: String

    public let contentType: String?

    /// The object's size in bytes.
    ///
    /// The API reports this as a decimal string. A response that omits it, or that carries a value
    /// this parser cannot read, yields `0`, so `0` does not always mean an empty object.
    public let size: Int64

    /// The Base64-encoded MD5 digest of the object's content.
    ///
    /// Cloud Storage omits it for composite objects and for objects whose content was never hashed,
    /// so it is not a reliable integrity check for every object.
    public let md5Hash: String?

    /// When the object was created.
    ///
    /// `nil` when the API's timestamp carries no fractional seconds: the parser requires them and
    /// returns nothing otherwise.
    public let timeCreated: Date?

    /// When the object's content or metadata last changed.
    ///
    /// Parsed under the same fractional-seconds rule as ``timeCreated``.
    public let updated: Date?

    /// The API's authenticated download URL for this object.
    ///
    /// It still needs the same `Authorization` header the client sends, so it is not a link you can
    /// hand out. Use `StorageClient.publicURL(for:)` for that.
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
    /// Builds an object from a JSON API response body.
    ///
    /// Only `name` and `bucket` are required; without either, this returns `nil` and the caller
    /// reports the body as invalid. Everything else degrades quietly: a missing or unparseable
    /// `size` becomes `0`, a missing `id` is synthesized, and a timestamp without fractional
    /// seconds becomes `nil`.
    static func fromJSON(_ json: [String: Any]) -> StorageObject? {
        guard
            let name = json["name"] as? String,
            let bucket = json["bucket"] as? String
        else {
            return nil
        }

        // The emulator can omit "id"; rebuild it from the generation instead.
        let id: String
        if let explicitId = json["id"] as? String {
            id = explicitId
        } else if let generation = json["generation"] as? String {
            id = "\(bucket)/\(name)#\(generation)"
        } else if let generationInt = json["generation"] as? Int64 {
            id = "\(bucket)/\(name)#\(generationInt)"
        } else {
            // Neither field is present: fall back to an id with no generation.
            id = "\(bucket)/\(name)"
        }

        let size: Int64
        if let sizeString = json["size"] as? String {
            size = Int64(sizeString) ?? 0
        } else if let sizeInt = json["size"] as? Int64 {
            size = sizeInt
        } else if let sizeInt = json["size"] as? Int {
            size = Int64(sizeInt)
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
