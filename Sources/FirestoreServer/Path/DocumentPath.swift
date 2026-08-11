/// A path that names a document: the thing that holds fields and can own subcollections.
///
/// A document path always has an even number of segments, at least two, because a document
/// always sits inside a collection.
///
/// For example:
/// - `users/abc123`
/// - `users/abc123/books/xyz`
/// - `users/abc123/books/xyz/chapters/ch1`
public struct DocumentPath: Sendable, Hashable {
    public let segments: [PathSegment]

    /// Creates a document path from segments, trapping if their count is odd or below two.
    internal init(segments: [PathSegment]) {
        precondition(segments.count >= 2 && segments.count % 2 == 0,
                     "Document path must have even number of segments (>= 2)")
        self.segments = segments
    }

    /// Parses a slash-separated path and checks that it names a document.
    ///
    /// - Parameter path: A path with an even number of segments, such as `users/abc123`.
    /// - Throws: `PathError.emptyPath` if the string yields no segments, or
    ///   `PathError.invalidDocumentPath` if the count is odd — that is, if it names a collection.
    public init(_ path: String) throws(PathError) {
        let resource = try ResourcePath(path)
        guard resource.isDocument else {
            throw .invalidDocumentPath(path)
        }
        self.segments = resource.segments
    }

    /// The last segment of the path.
    public var documentId: String {
        segments.last!.id
    }

    /// The collection this document belongs to, which always exists.
    public var parent: CollectionPath {
        CollectionPath(segments: Array(segments.dropLast()))
    }

    /// Returns the path of a subcollection under this document.
    ///
    /// The subcollection is a separate container: writing or deleting this document leaves the
    /// documents inside it untouched.
    ///
    /// - Parameter collectionId: A single segment naming the subcollection.
    public func collection(_ collectionId: String) -> CollectionPath {
        CollectionPath(segments: segments + [.collection(collectionId)])
    }

    /// The segments joined with `/`, without the database prefix.
    public var rawValue: String {
        segments.map(\.id).joined(separator: "/")
    }
}

extension DocumentPath: CustomStringConvertible {
    public var description: String {
        rawValue
    }
}
