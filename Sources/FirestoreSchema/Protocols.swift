import FirestoreServer

// MARK: - Schema Protocol

/// The requirements `@FirestoreSchema` fulfills on the struct it is applied to.
///
/// Conform manually only when hand-writing a schema; the macro generates all three members,
/// with `database` forwarded from the client's configuration.
public protocol FirestoreSchemaProtocol: Sendable {
    var database: DatabasePath { get }

    var client: FirestoreClient { get }

    init(client: FirestoreClient)
}

// MARK: - Generic Collection

/// A collection whose documents encode and decode as `Model`.
///
/// It pairs the collection ID the macro extracted from `@Collection` with the client supplied at
/// runtime, and is what `@FirestoreSchema` generates for collections that have no
/// sub-collections. Pass `parentPath` to address a sub-collection.
///
/// - Important: Read the collection ID from the instance. The static `collectionId` required by
///   `FirestoreCollectionProtocol` cannot be answered by a generic type and traps if called,
///   which is why this type overrides `reference` rather than inheriting the protocol default.
public struct FirestoreCollection<Model: Codable & Sendable>: FirestoreCollectionProtocol, Sendable {
    public typealias Document = FirestoreDocument<Model>

    public static var collectionId: String { _collectionId }
    private static var _collectionId: String { fatalError("Use instance") }

    public let collectionId: String
    public let database: DatabasePath
    public let client: FirestoreClient
    public let parentPath: String?

    public init(
        collectionId: String,
        database: DatabasePath,
        client: FirestoreClient,
        parentPath: String? = nil
    ) {
        self.collectionId = collectionId
        self.database = database
        self.client = client
        self.parentPath = parentPath
    }

    public var reference: CollectionReference {
        if let parentPath = parentPath {
            let fullPath = "\(parentPath)/\(collectionId)"
            // swiftlint:disable:next force_try
            return CollectionReference(database: database, path: try! CollectionPath(fullPath))
        } else {
            // swiftlint:disable:next force_try
            return CollectionReference(database: database, path: try! CollectionPath(collectionId))
        }
    }

    public func document(_ documentId: String) -> Document {
        Document(
            documentId: documentId,
            database: database,
            client: client,
            collectionPath: parentPath.map { "\($0)/\(collectionId)" } ?? collectionId
        )
    }
}

// MARK: - Generic Document

/// A handle to one document, whose value encodes and decodes as `Model`.
///
/// Holding one performs no request, and the document it names need not exist yet.
public struct FirestoreDocument<Model: Codable & Sendable>: FirestoreDocumentProtocol, Sendable {
    public let documentId: String
    public let database: DatabasePath
    public let client: FirestoreClient
    public let collectionPath: String

    public init(
        documentId: String,
        database: DatabasePath,
        client: FirestoreClient,
        collectionPath: String
    ) {
        self.documentId = documentId
        self.database = database
        self.client = client
        self.collectionPath = collectionPath
    }
}

// MARK: - Collection Protocol

/// A Firestore collection that knows the type of its documents.
///
/// Because `Model` is an associated type, none of the operations need a type argument: the
/// document element type of `getAll()` and the result of `document(_:).get()` follow from it.
/// The extension below supplies `reference` and the read operations, so a conforming type only
/// has to carry the client, the paths, and `document(_:)`.
///
/// ```swift
/// let schema = MySchema(client: firestoreClient)
/// let (users, nextPage) = try await schema.users.getAll()  // users is [User]
/// let user = try await schema.users.document("user123").get()  // inferred as User
/// ```
public protocol FirestoreCollectionProtocol: Sendable {
    associatedtype Model: Codable & Sendable

    associatedtype Document: FirestoreDocumentProtocol where Document.Model == Model

    /// The collection ID as written in `@Collection`.
    ///
    /// Types generated for a fixed collection return the literal. `FirestoreCollection` cannot
    /// answer it statically and traps instead, so prefer the instance value where one exists.
    static var collectionId: String { get }

    var database: DatabasePath { get }

    var client: FirestoreClient { get }

    /// The path of the parent document, or `nil` for a root collection.
    var parentPath: String? { get }

    /// The reference this collection resolves to: `parentPath/collectionId`, or just
    /// `collectionId` at the root.
    var reference: CollectionReference { get }

    /// Returns a handle for the document with this ID.
    ///
    /// No request is made and the document need not exist.
    func document(_ documentId: String) -> Document
}

extension FirestoreCollectionProtocol {
    public var reference: CollectionReference {
        if let parentPath = parentPath {
            let fullPath = "\(parentPath)/\(Self.collectionId)"
            // swiftlint:disable:next force_try
            return CollectionReference(database: database, path: try! CollectionPath(fullPath))
        } else {
            // swiftlint:disable:next force_try
            return CollectionReference(database: database, path: try! CollectionPath(Self.collectionId))
        }
    }

    /// Starts a query over this collection, decoding results as `Model`.
    public func query() -> Query<Model> {
        reference.query(as: Model.self)
    }

    /// Lists one page of documents in the collection, unfiltered and unordered.
    ///
    /// This is Firestore's list endpoint rather than a query: no filter or ordering is applied,
    /// and sub-collections are not traversed. Feed the returned token back in as `pageToken` to
    /// walk the rest; it is `nil` once the last page has been read.
    ///
    /// - Parameters:
    ///   - pageSize: How many documents to ask for in this request.
    ///   - pageToken: The token returned by the previous call, or `nil` for the first page.
    public func getAll(
        pageSize: Int = 100,
        pageToken: String? = nil
    ) async throws -> (documents: [Model], nextPageToken: String?) {
        try await client.listDocuments(
            in: reference,
            as: Model.self,
            pageSize: pageSize,
            pageToken: pageToken
        )
    }

    /// Runs the query and decodes every matching document.
    ///
    /// The whole result set comes back in one response, so a query that matches a large number
    /// of documents is bounded by the client's response buffer rather than paged.
    public func execute(_ query: Query<Model>) async throws -> [Model] {
        try await client.runQuery(query)
    }
}

// MARK: - Document Protocol

/// A Firestore document that knows the type it decodes to.
///
/// Because `Model` is an associated type, `get()` needs no type argument. The extension below
/// supplies `reference` and the four single-document operations.
///
/// ```swift
/// let schema = MySchema(client: firestoreClient)
/// let user = try await schema.users.document("user123").get()  // inferred as User
/// ```
public protocol FirestoreDocumentProtocol: Sendable {
    associatedtype Model: Codable & Sendable

    var documentId: String { get }

    var database: DatabasePath { get }

    var client: FirestoreClient { get }

    /// The path of the collection this document lives in, without the document ID.
    var collectionPath: String { get }

    /// The reference this document resolves to: `collectionPath/documentId`.
    var reference: DocumentReference { get }
}

extension FirestoreDocumentProtocol {
    public var reference: DocumentReference {
        let fullPath = "\(collectionPath)/\(documentId)"
        // swiftlint:disable:next force_try
        return DocumentReference(database: database, path: try! DocumentPath(fullPath))
    }

    /// Fetches the document and decodes it as `Model`.
    ///
    /// A missing document is an error, not an empty result: Firestore answers the GET with 404
    /// and the call throws `FirestoreError.api(.notFound)`.
    public func get() async throws -> Model {
        try await client.getDocument(reference, as: Model.self)
    }

    /// Creates the document at this path.
    ///
    /// The write is addressed to the parent collection with an explicit document ID, so it
    /// fails with `FirestoreError.api(.alreadyExists)` if something is already there. Use
    /// `update(data:)` when overwriting is the intent.
    public func create(data: Model) async throws {
        try await client.createDocument(reference, data: data)
    }

    /// Replaces the document with the encoded value.
    ///
    /// The PATCH carries no update mask, so this is a whole-document write rather than a merge:
    /// fields the stored document has and `data` does not are dropped. No `currentDocument`
    /// precondition is sent either, so concurrent writers are resolved last-write-wins.
    public func update(data: Model) async throws {
        try await client.updateDocument(reference, data: data)
    }

    /// Deletes the document.
    ///
    /// No `currentDocument` precondition is sent, so the call does not assert that the document
    /// exists first.
    public func delete() async throws {
        try await client.deleteDocument(reference)
    }
}
