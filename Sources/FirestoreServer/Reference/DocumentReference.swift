/// A pointer to the location of a document, in a specific database.
///
/// Building one costs nothing and touches no network: it names a place, and the document it
/// names need not exist. Reads and writes go through the client that produced it.
///
/// ```swift
/// let userRef = firestore.collection("users").document("abc")
/// let bookRef = userRef.collection("books").document("xyz")
/// ```
public struct DocumentReference: Sendable, Hashable {
    public let database: DatabasePath

    /// The path within the database, with no `projects/…/documents` prefix.
    public let path: DocumentPath

    public init(database: DatabasePath, path: DocumentPath) {
        self.database = database
        self.path = path
    }

    public var documentId: String {
        path.documentId
    }

    /// The collection this document belongs to, which always exists.
    public var parent: CollectionReference {
        CollectionReference(database: database, path: path.parent)
    }

    /// Returns a reference to a subcollection under this document.
    ///
    /// The subcollection is a separate container: deleting this document leaves the documents
    /// inside it in place, still reachable by path.
    ///
    /// - Parameter collectionId: A single segment naming the subcollection.
    public func collection(_ collectionId: String) -> CollectionReference {
        CollectionReference(database: database, path: path.collection(collectionId))
    }

    // MARK: - REST API Paths

    /// The `name` the REST API expects when reading, patching, or deleting the document.
    ///
    /// For example: `projects/my-project/databases/(default)/documents/users/abc`.
    public var restName: String {
        "\(database.documentsPath)/\(path.rawValue)"
    }

    /// The path relative to the database's document root, such as `users/abc`.
    ///
    /// This is the short form that thrown errors report; requests are addressed with `restName`.
    public var restDocumentPath: String {
        path.rawValue
    }
}

extension DocumentReference: CustomStringConvertible {
    public var description: String {
        path.rawValue
    }
}
