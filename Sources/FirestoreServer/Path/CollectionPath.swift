/// A path that names a collection: the container documents live in.
///
/// A collection path always has an odd number of segments, since every second segment is a
/// document ID.
///
/// For example:
/// - `users` (a root collection)
/// - `users/abc123/books` (a subcollection)
/// - `users/abc123/books/xyz/chapters` (a nested subcollection)
public struct CollectionPath: Sendable, Hashable {
    public let segments: [PathSegment]

    /// Creates a collection path from segments, trapping if their count is even.
    internal init(segments: [PathSegment]) {
        precondition(segments.count % 2 == 1, "Collection path must have odd number of segments")
        self.segments = segments
    }

    /// Parses a slash-separated path and checks that it names a collection.
    ///
    /// - Parameter path: A path with an odd number of segments, such as `users` or
    ///   `users/abc123/books`.
    /// - Throws: `PathError.emptyPath` if the string yields no segments, or
    ///   `PathError.invalidCollectionPath` if the count is even — that is, if it names a document.
    public init(_ path: String) throws(PathError) {
        let resource = try ResourcePath(path)
        guard resource.isCollection else {
            throw .invalidCollectionPath(path)
        }
        self.segments = resource.segments
    }

    /// The last segment of the path.
    public var collectionId: String {
        segments.last!.id
    }

    /// The document this collection hangs off, or `nil` for a root collection.
    public var parent: DocumentPath? {
        guard segments.count > 1 else { return nil }
        return DocumentPath(segments: Array(segments.dropLast()))
    }

    /// Returns the path of a document in this collection.
    ///
    /// This only builds a path — nothing is read or written, and the document need not exist.
    ///
    /// - Parameter documentId: A single segment naming the document.
    public func document(_ documentId: String) -> DocumentPath {
        DocumentPath(segments: segments + [.document(documentId)])
    }

    /// The segments joined with `/`, without the database prefix.
    public var rawValue: String {
        segments.map(\.id).joined(separator: "/")
    }
}

extension CollectionPath: CustomStringConvertible {
    public var description: String {
        rawValue
    }
}
