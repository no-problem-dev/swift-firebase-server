import Foundation
import Internal

/// Cloud Storage APIエラー
public enum StorageError: Error, Sendable {
    /// 共通APIエラー
    case api(APIError)

    /// ファイルサイズ超過
    case fileTooLarge(size: Int64, maxSize: Int64)

    /// 無効なコンテンツタイプ
    case invalidContentType(contentType: String)

    /// 無効なパス
    case invalidPath(path: String)
}

// MARK: - Convenience Accessors

extension StorageError {
    /// オブジェクトが見つからない
    public static func notFound(path: String) -> StorageError {
        .api(.notFound(path: path))
    }

    /// 権限がない
    public static func permissionDenied(message: String) -> StorageError {
        .api(.permissionDenied(message: message))
    }

    /// 認証エラー
    public static func unauthenticated(message: String) -> StorageError {
        .api(.unauthenticated(message: message))
    }

    /// 不正な引数
    public static func invalidArgument(message: String) -> StorageError {
        .api(.invalidArgument(message: message))
    }

    /// リソースが既に存在する
    public static func alreadyExists(path: String) -> StorageError {
        .api(.alreadyExists(path: path))
    }

    /// レート制限
    public static func resourceExhausted(message: String) -> StorageError {
        .api(.resourceExhausted(message: message))
    }

    /// サーバー内部エラー
    public static func internalError(message: String) -> StorageError {
        .api(.internalError(message: message))
    }

    /// サービス利用不可
    public static func unavailable(message: String) -> StorageError {
        .api(.unavailable(message: message))
    }

    /// ネットワークエラー
    public static func network(underlying: Error) -> StorageError {
        .api(.network(underlying: underlying))
    }

    /// 不明なエラー
    public static func unknown(statusCode: Int, message: String) -> StorageError {
        .api(.unknown(statusCode: statusCode, message: message))
    }
}

extension StorageError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .api(let apiError):
            return apiError.description
        case .fileTooLarge(let size, let maxSize):
            return "File too large: \(size) bytes (max: \(maxSize) bytes)"
        case .invalidContentType(let contentType):
            return "Invalid content type: \(contentType)"
        case .invalidPath(let path):
            return "Invalid storage path: \(path)"
        }
    }
}

// MARK: - HTTP Status Code Mapping

extension StorageError {
    /// HTTPステータスコードとレスポンスボディからエラーを生成
    public static func fromHTTPResponse(statusCode: Int, body: Data?, path: String? = nil) -> StorageError {
        .api(APIError.fromHTTPResponse(statusCode: statusCode, body: body, path: path))
    }
}
