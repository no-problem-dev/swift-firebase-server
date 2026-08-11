/// A pointer to the location of a collection, in a specific database.
///
/// Building one costs nothing and touches no network: it names a place, and the collection it
/// names need not exist. Reads and writes go through the client that produced it.
///
/// ```swift
/// let usersRef = firestore.collection("users")
/// let booksRef = usersRef.document("abc").collection("books")
/// ```
public struct CollectionReference: Sendable, Hashable {
    public let database: DatabasePath

    /// The path within the database, with no `projects/…/documents` prefix.
    public let path: CollectionPath

    public init(database: DatabasePath, path: CollectionPath) {
        self.database = database
        self.path = path
    }

    public var collectionId: String {
        path.collectionId
    }

    /// The document this collection hangs off, or `nil` for a root collection.
    public var parent: DocumentReference? {
        guard let parentPath = path.parent else { return nil }
        return DocumentReference(database: database, path: parentPath)
    }

    /// Returns a reference to a document in this collection.
    ///
    /// - Parameter documentId: A single segment naming the document.
    public func document(_ documentId: String) -> DocumentReference {
        DocumentReference(database: database, path: path.document(documentId))
    }

    // MARK: - REST API Paths

    /// The `parent` the REST API expects for `createDocument`, `listDocuments`, and `runQuery`.
    ///
    /// It names the document that owns the collection, or the database's document root when this
    /// is a root collection. For example:
    /// `projects/my-project/databases/(default)/documents` or
    /// `projects/my-project/databases/(default)/documents/users/abc`.
    public var restParent: String {
        if let parentPath = path.parent {
            return "\(database.documentsPath)/\(parentPath.rawValue)"
        } else {
            return database.documentsPath
        }
    }

    /// The `collectionId` the REST API expects alongside `restParent`.
    public var restCollectionId: String {
        collectionId
    }

    /// The collection's full REST resource name.
    ///
    /// For example: `projects/my-project/databases/(default)/documents/users`.
    public var restPath: String {
        "\(database.documentsPath)/\(path.rawValue)"
    }
}

extension CollectionReference: CustomStringConvertible {
    public var description: String {
        path.rawValue
    }
}

// MARK: - Query Builder

extension CollectionReference {
    /// Starts a query over this collection.
    ///
    /// The returned builder is inert until it is handed to a client to run.
    ///
    /// - Parameter type: The type each matching document is decoded into.
    public func query<T: Decodable & Sendable>(as type: T.Type) -> Query<T> {
        Query(collection: self)
    }
}
