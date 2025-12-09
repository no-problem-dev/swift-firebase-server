import Foundation

/// Firestore APIエラー
public enum FirestoreError: Error, Sendable {
    /// ドキュメントが見つからない
    case notFound(path: String)

    /// 権限がない
    case permissionDenied(message: String)

    /// 認証エラー
    case unauthenticated(message: String)

    /// 不正な引数
    case invalidArgument(message: String)

    /// リソースが既に存在する
    case alreadyExists(path: String)

    /// レート制限
    case resourceExhausted(message: String)

    /// サーバー内部エラー
    case internalError(message: String)

    /// サービス利用不可
    case unavailable(message: String)

    /// ネットワークエラー
    case network(underlying: Error)

    /// デコードエラー
    case decoding(underlying: Error)

    /// エンコードエラー
    case encoding(underlying: Error)

    /// 不明なエラー
    case unknown(statusCode: Int, message: String)
}

extension FirestoreError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notFound(let path):
            return "Document not found: \(path)"
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        case .unauthenticated(let message):
            return "Unauthenticated: \(message)"
        case .invalidArgument(let message):
            return "Invalid argument: \(message)"
        case .alreadyExists(let path):
            return "Document already exists: \(path)"
        case .resourceExhausted(let message):
            return "Resource exhausted: \(message)"
        case .internalError(let message):
            return "Internal error: \(message)"
        case .unavailable(let message):
            return "Service unavailable: \(message)"
        case .network(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .decoding(let underlying):
            return "Decoding error: \(underlying.localizedDescription)"
        case .encoding(let underlying):
            return "Encoding error: \(underlying.localizedDescription)"
        case .unknown(let statusCode, let message):
            return "Unknown error (HTTP \(statusCode)): \(message)"
        }
    }
}

// MARK: - HTTP Status Code Mapping

extension FirestoreError {
    /// HTTPステータスコードとレスポンスボディからエラーを生成
    static func fromHTTPResponse(statusCode: Int, body: Data?, path: String? = nil) -> FirestoreError {
        let message = body.flatMap { String(data: $0, encoding: .utf8) } ?? "No response body"

        switch statusCode {
        case 400:
            return .invalidArgument(message: message)
        case 401:
            return .unauthenticated(message: message)
        case 403:
            return .permissionDenied(message: message)
        case 404:
            return .notFound(path: path ?? "unknown")
        case 409:
            return .alreadyExists(path: path ?? "unknown")
        case 429:
            return .resourceExhausted(message: message)
        case 500:
            return .internalError(message: message)
        case 503:
            return .unavailable(message: message)
        default:
            return .unknown(statusCode: statusCode, message: message)
        }
    }
}
