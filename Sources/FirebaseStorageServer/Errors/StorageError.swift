import Foundation
import Internal

/// A failure from a Cloud Storage operation.
public enum StorageError: Error, Sendable {
    /// A status-level failure from the API, mapped by HTTP status code.
    case api(APIError)

    /// The object name is one Cloud Storage does not accept, caught before any request went out.
    ///
    /// Raised by every ``StorageClient`` call that takes a path: the name was empty, was `.` or
    /// `..`, or held a carriage return or line feed.
    case invalidPath(path: String)
}

// MARK: - Convenience Accessors

extension StorageError {
    /// The object does not exist. Mapped from HTTP 404.
    public static func notFound(path: String) -> StorageError {
        .api(.notFound(path: path))
    }

    /// The credentials are valid but not authorized for this object or bucket. Mapped from HTTP 403.
    public static func permissionDenied(message: String) -> StorageError {
        .api(.permissionDenied(message: message))
    }

    /// The bearer token is missing, malformed, or expired. Mapped from HTTP 401.
    public static func unauthenticated(message: String) -> StorageError {
        .api(.unauthenticated(message: message))
    }

    /// The request was malformed. Mapped from HTTP 400, and also raised locally when a 200 response
    /// body is not a parseable object resource.
    public static func invalidArgument(message: String) -> StorageError {
        .api(.invalidArgument(message: message))
    }

    /// The object already exists under a precondition that forbids overwriting. Mapped from HTTP 409.
    public static func alreadyExists(path: String) -> StorageError {
        .api(.alreadyExists(path: path))
    }

    /// Rate limited or over quota. Mapped from HTTP 429; retry with backoff.
    public static func resourceExhausted(message: String) -> StorageError {
        .api(.resourceExhausted(message: message))
    }

    /// The service failed while handling the request. Mapped from HTTP 500.
    public static func internalError(message: String) -> StorageError {
        .api(.internalError(message: message))
    }

    /// The service is temporarily down. Mapped from HTTP 503; retry with backoff.
    public static func unavailable(message: String) -> StorageError {
        .api(.unavailable(message: message))
    }

    /// The request never produced a response. Wraps a transport-level failure; no status code was
    /// received.
    public static func network(underlying: Error) -> StorageError {
        .api(.network(underlying: underlying))
    }

    /// Any status the mapping does not recognize. Also carries `-1` for failures reported by
    /// `StorageClient.deleteMultiple(paths:)` that were not `StorageError` to begin with.
    public static func unknown(statusCode: Int, message: String) -> StorageError {
        .api(.unknown(statusCode: statusCode, message: message))
    }
}

extension StorageError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .api(let apiError):
            return apiError.description
        case .invalidPath(let path):
            return "Invalid storage path: \(path)"
        }
    }
}

// MARK: - HTTP Status Code Mapping

extension StorageError {
    /// Maps a failed HTTP response onto an error case.
    ///
    /// 400, 401, 403, 404, 409, 429, 500, and 503 each get their own case; every other status
    /// becomes `.unknown` carrying the status code. The response body is decoded as UTF-8 into the
    /// error's message, so it can hold the API's raw error JSON.
    /// - Parameters:
    ///   - statusCode: The status the API answered with.
    ///   - body: The response body, used as the error message.
    ///   - path: The object path, recorded on the cases that identify a resource. Defaults to
    ///     `"unknown"` when not supplied.
    public static func fromHTTPResponse(statusCode: Int, body: Data?, path: String? = nil) -> StorageError {
        .api(APIError.fromHTTPResponse(statusCode: statusCode, body: body, path: path))
    }
}
