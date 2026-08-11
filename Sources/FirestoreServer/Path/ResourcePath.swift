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
    /// The segments themselves are not validated: their characters and length are passed through
    /// untouched, and it is Firestore that rejects an ID it does not accept.
    ///
    /// - Parameter path: A slash-separated path such as `users/abc123/books`.
    /// - Throws: `PathError.emptyPath` if the string yields no segments.
    public init(_ path: String) throws(PathError) {
        let parts = path.split(separator: "/").map(String.init)
        guard !parts.isEmpty else {
            throw .emptyPath
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
