/// A path to a Firestore resource, which is either a collection or a document.
///
/// Firestore paths alternate between the two, so the segment count alone decides which kind a
/// path names:
/// - A collection holds documents and has an odd number of segments.
/// - A document holds fields and has an even number of segments.
/// - A collection under a document is a subcollection; nesting has no fixed depth here.
///
/// For example:
/// - `users` is a collection (1 segment)
/// - `users/abc123` is a document (2 segments)
/// - `users/abc123/books` is a subcollection (3 segments)
/// - `users/abc123/books/xyz` is a document (4 segments)
public struct ResourcePath: Sendable, Hashable {
    public let segments: [PathSegment]

    /// Creates a path from segments that are already tagged, without checking their parity.
    internal init(segments: [PathSegment]) {
        self.segments = segments
    }

    /// Parses a slash-separated path, tagging segments as collection and document in turn.
    ///
    /// Empty components are dropped, so leading, trailing, and repeated slashes are tolerated.
    /// Every remaining segment is checked against the rules Firestore applies to collection and
    /// document IDs, so an ID the server would refuse is refused here instead of becoming a
    /// request.
    ///
    /// - Parameter path: A slash-separated path such as `users/abc123/books`.
    /// - Throws: `PathError.emptyPath` if the string yields no segments, or
    ///   `PathError.invalidCharacters` naming the first segment Firestore does not accept.
    public init(_ path: String) throws(PathError) {
        let parts = path.split(separator: "/").map(String.init)
        guard !parts.isEmpty else {
            throw .emptyPath
        }

        for part in parts {
            try Self.validateSegment(part)
        }

        // Read the segments alternately as collection, document, collection, ...
        var segments: [PathSegment] = []
        for (index, part) in parts.enumerated() {
            if index % 2 == 0 {
                segments.append(.collection(part))
            } else {
                segments.append(.document(part))
            }
        }
        self.segments = segments
    }

    /// Checks one path segment against Firestore's ID rules.
    ///
    /// The rules, each confirmed against the Firestore emulator, are that an ID may not be `.` or
    /// `..`, may not match `__.*__` (those are reserved), and may not exceed 1,500 bytes. `/` is
    /// not checked because it is the separator the path was split on.
    ///
    /// - Throws: `PathError.invalidCharacters` carrying the offending segment.
    static func validateSegment(_ id: String) throws(PathError) {
        if id == "." || id == ".." {
            throw .invalidCharacters(id)
        }

        if id.count >= 4, id.hasPrefix("__"), id.hasSuffix("__") {
            throw .invalidCharacters(id)
        }

        if id.utf8.count > 1500 {
            throw .invalidCharacters(id)
        }
    }

    /// Whether the path has an odd number of segments and so names a collection.
    public var isCollection: Bool {
        segments.count % 2 == 1
    }

    /// Whether the path has a non-zero, even number of segments and so names a document.
    public var isDocument: Bool {
        segments.count % 2 == 0 && !segments.isEmpty
    }

    /// Narrows the path to a collection path, or returns `nil` if it names a document.
    public func asCollection() -> CollectionPath? {
        guard isCollection else { return nil }
        return CollectionPath(segments: segments)
    }

    /// Narrows the path to a document path, or returns `nil` if it names a collection.
    public func asDocument() -> DocumentPath? {
        guard isDocument else { return nil }
        return DocumentPath(segments: segments)
    }

    /// The segments joined with `/`, without the database prefix.
    public var rawValue: String {
        segments.map(\.id).joined(separator: "/")
    }
}

extension ResourcePath: CustomStringConvertible {
    public var description: String {
        rawValue
    }
}
