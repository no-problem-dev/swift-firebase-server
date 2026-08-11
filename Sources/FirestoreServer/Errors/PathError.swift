/// A path string that cannot be read as the Firestore resource it was asked to be.
///
/// These come out of parsing alone, before any request is made, and they turn on the number of
/// segments rather than on whether the resource exists.
public enum PathError: Error, Sendable, Hashable {
    /// The string held no segments at all, such as `""` or `"/"`.
    case emptyPath

    /// The path has an even number of segments, so it names a document, not a collection.
    case invalidCollectionPath(String)

    /// The path has an odd number of segments, so it names a collection, not a document.
    case invalidDocumentPath(String)

    /// One segment is an ID Firestore does not accept, and the payload is that segment.
    ///
    /// Raised while parsing, for a segment that is `.` or `..`, matches the reserved `__.*__`
    /// shape, or runs past 1,500 bytes.
    case invalidCharacters(String)
}

extension PathError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .emptyPath:
            return "Path cannot be empty"
        case .invalidCollectionPath(let path):
            return "Invalid collection path: '\(path)' (must have odd number of segments)"
        case .invalidDocumentPath(let path):
            return "Invalid document path: '\(path)' (must have even number of segments >= 2)"
        case .invalidCharacters(let segment):
            return "Path segment is not a valid Firestore ID: '\(segment)'"
        }
    }
}
