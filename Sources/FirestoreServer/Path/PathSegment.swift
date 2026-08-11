/// One segment of a Firestore path, tagged with what it names.
///
/// A Firestore path reads `collection/document/collection/document/…`, so the tag follows from
/// the segment's position rather than from anything in the ID itself: the first segment is a
/// collection, the second a document, and so on.
public enum PathSegment: Sendable, Hashable {
    case collection(String)
    case document(String)

    public var id: String {
        switch self {
        case .collection(let id), .document(let id):
            return id
        }
    }

    public var isCollection: Bool {
        if case .collection = self { return true }
        return false
    }

    public var isDocument: Bool {
        if case .document = self { return true }
        return false
    }
}
