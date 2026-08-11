import Foundation

/// A failure shared by every Firebase REST service.
///
/// Firestore and Cloud Storage each wrap this in their own error type, so anything that is not
/// specific to one service is reported here, carrying the HTTP status it was derived from.
public enum APIError: Error, Sendable {
    /// The resource does not exist (HTTP 404).
    ///
    /// `path` is whatever path the caller supplied, or `"unknown"` when it supplied none.
    case notFound(path: String)

    /// The credentials were accepted but do not grant access to the resource (HTTP 403).
    case permissionDenied(message: String)

    /// The request carried no usable credentials, or the token had expired (HTTP 401).
    case unauthenticated(message: String)

    /// The service rejected the request as malformed (HTTP 400).
    case invalidArgument(message: String)

    /// The resource already exists (HTTP 409).
    ///
    /// `path` is whatever path the caller supplied, or `"unknown"` when it supplied none.
    case alreadyExists(path: String)

    /// A quota or rate limit was reached (HTTP 429). Retry with backoff.
    case resourceExhausted(message: String)

    /// The service failed on its own side (HTTP 500).
    case internalError(message: String)

    /// The service is temporarily unable to serve the request (HTTP 503). Retry with backoff.
    case unavailable(message: String)

    /// The request never produced an HTTP response, such as a connection failure or a timeout.
    case network(underlying: Error)

    /// A status this type does not map, which includes 502 and 504.
    ///
    /// `message` holds the response body decoded as UTF-8.
    case unknown(statusCode: Int, message: String)
}

extension APIError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notFound(let path):
            return "Resource not found: \(path)"
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        case .unauthenticated(let message):
            return "Unauthenticated: \(message)"
        case .invalidArgument(let message):
            return "Invalid argument: \(message)"
        case .alreadyExists(let path):
            return "Resource already exists: \(path)"
        case .resourceExhausted(let message):
            return "Resource exhausted: \(message)"
        case .internalError(let message):
            return "Internal error: \(message)"
        case .unavailable(let message):
            return "Service unavailable: \(message)"
        case .network(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .unknown(let statusCode, let message):
            return "Unknown error (HTTP \(statusCode)): \(message)"
        }
    }
}

// MARK: - HTTP Status Code Mapping

extension APIError {
    /// Maps an HTTP status code and response body onto an error case.
    ///
    /// Only 400, 401, 403, 404, 409, 429, 500 and 503 are mapped; every other status, including
    /// any 2xx, becomes `.unknown` carrying the original code.
    ///
    /// - Parameters:
    ///   - statusCode: The status code of the response.
    ///   - body: The raw response body, decoded as UTF-8 and used as the error message. A body
    ///     that is nil or not valid UTF-8 yields the message `"No response body"`.
    ///   - path: The resource path to record. It is kept only by `.notFound` and
    ///     `.alreadyExists`, which fall back to `"unknown"` when it is nil.
    public static func fromHTTPResponse(
        statusCode: Int,
        body: Data?,
        path: String? = nil
    ) -> APIError {
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
