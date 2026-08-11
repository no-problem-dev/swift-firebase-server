import Foundation
import FirebaseStorageServer

// MARK: - Schema Protocol

/// The root of a generated storage schema.
///
/// `@StorageSchema` conforms your type to this. The schema owns the one client every folder and
/// object below it hands down, so the whole tree addresses a single bucket.
public protocol StorageSchemaProtocol: Sendable {
    var client: StorageClient { get }

    init(client: StorageClient)
}

// MARK: - Folder Protocol

/// One level of a storage path.
///
/// `@Folder` conforms your type to this. Cloud Storage buckets are flat, so a folder is only a
/// naming convention: it contributes a segment to the object name, and creates nothing on its own.
public protocol StorageFolderProtocol: Sendable {
    /// The single segment this level contributes to the path.
    static var folderName: String { get }

    var client: StorageClient { get }

    /// The path of the enclosing folder, or `nil` for a folder that sits directly under the schema
    /// root.
    var parentPath: String? { get }

    /// The path from the bucket root down to this folder, with no trailing slash.
    var path: String { get }
}

extension StorageFolderProtocol {
    public var path: String {
        if let parentPath = parentPath {
            return "\(parentPath)/\(Self.folderName)"
        } else {
            return Self.folderName
        }
    }
}

// MARK: - Object Protocol

/// A single object's address, bound to the client that can act on it.
///
/// `@Object` conforms your type to this, which is what supplies the upload, download, delete,
/// metadata, and public-URL operations below.
public protocol StorageObjectPathProtocol: Sendable {
    /// The name given to `@Object`.
    ///
    /// It identifies the declaration only. The built path uses ``objectId``, so this string never
    /// reaches Cloud Storage.
    static var baseName: String { get }

    var client: StorageClient { get }

    /// The path of the folder this object sits in.
    var parentPath: String { get }

    /// The per-instance name, such as a user ID, that distinguishes this object from its siblings.
    var objectId: String { get }

    /// The extension appended to the path, which also decides the Content-Type sent on upload.
    var fileExtension: FileExtension { get }

    /// The full object name inside the bucket.
    var path: String { get }
}

extension StorageObjectPathProtocol {
    public var path: String {
        "\(parentPath)/\(objectId)\(fileExtension.withDot)"
    }

    /// The MIME type implied by the file extension, sent as `Content-Type` on upload.
    public var contentType: String {
        fileExtension.contentType
    }
}

// MARK: - Object Operations

extension StorageObjectPathProtocol {
    /// Uploads data to this path, tagging it with the Content-Type the extension implies.
    ///
    /// Overwrites whatever is already there — Cloud Storage has no create-only mode unless a
    /// precondition is sent, and this sends none.
    public func upload(data: Data) async throws -> StorageObject {
        try await client.upload(data: data, path: path, contentType: contentType)
    }

    /// Downloads this object's bytes in full.
    ///
    /// - Throws: `StorageError.notFound` when the object does not exist.
    public func download() async throws -> Data {
        try await client.download(path: path)
    }

    /// Deletes this object.
    ///
    /// - Throws: `StorageError.notFound` when the object does not exist; deleting a missing object
    ///   is not a no-op.
    public func delete() async throws {
        try await client.delete(path: path)
    }

    /// Fetches this object's metadata without transferring its content.
    ///
    /// - Throws: `StorageError.notFound` when the object does not exist.
    public func getMetadata() async throws -> StorageObject {
        try await client.getMetadata(path: path)
    }

    /// The unauthenticated URL for this object.
    ///
    /// Unsigned and non-expiring, so it only resolves for objects the bucket grants public read on.
    public var publicURL: URL {
        client.publicURL(for: path)
    }
}
