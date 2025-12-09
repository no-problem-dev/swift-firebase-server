import Foundation
import StorageServer

// MARK: - Schema Protocol

/// Storageスキーマのルートプロトコル
public protocol StorageSchemaProtocol: Sendable {
    /// StorageClientへの参照
    var client: StorageClient { get }

    init(client: StorageClient)
}

// MARK: - Folder Protocol

/// Storageフォルダを表すプロトコル
public protocol StorageFolderProtocol: Sendable {
    /// フォルダ名
    static var folderName: String { get }

    /// StorageClientへの参照
    var client: StorageClient { get }

    /// 親フォルダのパス（ルートフォルダの場合はnil）
    var parentPath: String? { get }

    /// このフォルダの完全パス
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

/// Storageオブジェクト（ファイル）のパスを表すプロトコル
public protocol StorageObjectPathProtocol: Sendable {
    /// ベース名（拡張子なし）
    static var baseName: String { get }

    /// StorageClientへの参照
    var client: StorageClient { get }

    /// 親フォルダのパス
    var parentPath: String { get }

    /// オブジェクトID
    var objectId: String { get }

    /// ファイル拡張子
    var fileExtension: FileExtension { get }

    /// 完全なオブジェクトパス
    var path: String { get }
}

extension StorageObjectPathProtocol {
    public var path: String {
        "\(parentPath)/\(objectId)\(fileExtension.withDot)"
    }

    /// Content-Type
    public var contentType: String {
        fileExtension.contentType
    }
}

// MARK: - Object Operations

extension StorageObjectPathProtocol {
    /// ファイルをアップロード
    /// - Parameters:
    ///   - data: アップロードするデータ
    ///   - authorization: 認証トークン
    /// - Returns: アップロードされたオブジェクトのメタデータ
    public func upload(
        data: Data,
        authorization: String
    ) async throws -> StorageObject {
        try await client.upload(
            data: data,
            path: path,
            contentType: contentType,
            authorization: authorization
        )
    }

    /// ファイルをダウンロード
    /// - Parameter authorization: 認証トークン
    /// - Returns: ファイルデータ
    public func download(authorization: String) async throws -> Data {
        try await client.download(path: path, authorization: authorization)
    }

    /// ファイルを削除
    /// - Parameter authorization: 認証トークン
    public func delete(authorization: String) async throws {
        try await client.delete(path: path, authorization: authorization)
    }

    /// メタデータを取得
    /// - Parameter authorization: 認証トークン
    /// - Returns: オブジェクトのメタデータ
    public func getMetadata(authorization: String) async throws -> StorageObject {
        try await client.getMetadata(path: path, authorization: authorization)
    }

    /// 公開URLを取得
    public var publicURL: URL {
        client.publicURL(for: path)
    }
}
