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

    /// The path holds a character Firestore does not accept in an ID.
    ///
    /// Parsing does not inspect segment characters, so this case is for callers doing their own
    /// validation; the server is what rejects a bad ID otherwise.
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
        case .invalidCharacters(let path):
            return "Path contains invalid characters: '\(path)'"
        }
    }
}
