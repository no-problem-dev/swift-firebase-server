import Foundation
import Internal

/// Firestore APIエラー
public enum FirestoreError: Error, Sendable {
    /// 共通APIエラー
    case api(APIError)

    /// デコードエラー（Firestore固有）
    case decoding(underlying: Error)

    /// エンコードエラー（Firestore固有）
    case encoding(underlying: Error)
}

// MARK: - Convenience Accessors

extension FirestoreError {
    /// ドキュメントが見つからない
    public static func notFound(path: String) -> FirestoreError {
        .api(.notFound(path: path))
    }

    /// 権限がない
    public static func permissionDenied(message: String) -> FirestoreError {
        .api(.permissionDenied(message: message))
    }

    /// 認証エラー
    public static func unauthenticated(message: String) -> FirestoreError {
        .api(.unauthenticated(message: message))
    }

    /// 不正な引数
    public static func invalidArgument(message: String) -> FirestoreError {
        .api(.invalidArgument(message: message))
    }

    /// リソースが既に存在する
    public static func alreadyExists(path: String) -> FirestoreError {
        .api(.alreadyExists(path: path))
    }

    /// レート制限
    public static func resourceExhausted(message: String) -> FirestoreError {
        .api(.resourceExhausted(message: message))
    }

    /// サーバー内部エラー
    public static func internalError(message: String) -> FirestoreError {
        .api(.internalError(message: message))
    }

    /// サービス利用不可
    public static func unavailable(message: String) -> FirestoreError {
        .api(.unavailable(message: message))
    }

    /// ネットワークエラー
    public static func network(underlying: Error) -> FirestoreError {
        .api(.network(underlying: underlying))
    }

    /// 不明なエラー
    public static func unknown(statusCode: Int, message: String) -> FirestoreError {
        .api(.unknown(statusCode: statusCode, message: message))
    }
}

extension FirestoreError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .api(let apiError):
            return apiError.description
        case .decoding(let underlying):
            return "Decoding error: \(underlying.localizedDescription)"
        case .encoding(let underlying):
            return "Encoding error: \(underlying.localizedDescription)"
        }
    }
}

// MARK: - HTTP Status Code Mapping

extension FirestoreError {
    /// HTTPステータスコードとレスポンスボディからエラーを生成
    public static func fromHTTPResponse(statusCode: Int, body: Data?, path: String? = nil) -> FirestoreError {
        .api(APIError.fromHTTPResponse(statusCode: statusCode, body: body, path: path))
    }
}
