import Foundation
import Internal

/// Something a Firestore call can fail with.
///
/// Every failure the operations throw is `api`, carrying what the REST endpoint reported. The
/// coders throw `DecodingError` and `EncodingError` of their own rather than wrapping them, so
/// catch those separately; the two coding cases here are for callers that want one type.
public enum FirestoreError: Error, Sendable {
    /// A failure the REST API reported, mapped from the HTTP status.
    case api(APIError)

    /// Wraps a failure to turn a stored document into a Swift value.
    case decoding(underlying: Error)

    /// Wraps a failure to turn a Swift value into Firestore fields.
    case encoding(underlying: Error)
}

// MARK: - Convenience Accessors

extension FirestoreError {
    /// The document or collection does not exist (HTTP 404).
    public static func notFound(path: String) -> FirestoreError {
        .api(.notFound(path: path))
    }

    /// Security rules or IAM refused the call (HTTP 403).
    public static func permissionDenied(message: String) -> FirestoreError {
        .api(.permissionDenied(message: message))
    }

    /// The bearer token was missing, malformed, or expired (HTTP 401).
    public static func unauthenticated(message: String) -> FirestoreError {
        .api(.unauthenticated(message: message))
    }

    /// The request itself was rejected, such as an unindexed or malformed query (HTTP 400).
    public static func invalidArgument(message: String) -> FirestoreError {
        .api(.invalidArgument(message: message))
    }

    /// A document with that ID is already there, which is how a create loses the race (HTTP 409).
    public static func alreadyExists(path: String) -> FirestoreError {
        .api(.alreadyExists(path: path))
    }

    /// Rate limited or out of quota; worth retrying with backoff (HTTP 429).
    public static func resourceExhausted(message: String) -> FirestoreError {
        .api(.resourceExhausted(message: message))
    }

    /// The server failed while handling the request (HTTP 500).
    public static func internalError(message: String) -> FirestoreError {
        .api(.internalError(message: message))
    }

    /// The service is temporarily down; worth retrying with backoff (HTTP 503).
    public static func unavailable(message: String) -> FirestoreError {
        .api(.unavailable(message: message))
    }

    /// The request never got an answer, wrapping the transport failure.
    public static func network(underlying: Error) -> FirestoreError {
        .api(.network(underlying: underlying))
    }

    /// A status this package does not map, kept with the raw status code and body.
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
    /// Maps a failed HTTP response onto a case of this error.
    ///
    /// 400, 401, 403, 404, 409, 429, 500, and 503 map to their named cases; anything else,
    /// including 412 from an unmet precondition, lands in `unknown` with the status kept. The
    /// body is carried through as a UTF-8 string, so it is the raw JSON error Firestore returned.
    ///
    /// - Parameters:
    ///   - statusCode: The HTTP status of the response.
    ///   - body: The response body, used as the error message.
    ///   - path: The resource path the request was for. For 404 and 409 the body is dropped and
    ///     this is all the error carries, so passing `nil` leaves the literal string `unknown`.
    public static func fromHTTPResponse(statusCode: Int, body: Data?, path: String? = nil) -> FirestoreError {
        .api(APIError.fromHTTPResponse(statusCode: statusCode, body: body, path: path))
    }
}
