import AsyncHTTPClient
import Foundation
import Internal
import NIOCore
import NIOHTTP1

// MARK: - Document Operations

extension FirestoreClient {
    // MARK: - Get Document

    /// Reads a document and decodes its fields into the given type.
    ///
    /// A missing document is an error, not an empty result: this throws rather than returning
    /// `nil`, so catch `FirestoreError.api(.notFound)` if absence is expected.
    ///
    /// - Parameters:
    ///   - reference: The document to read.
    ///   - type: The type to decode the document's fields into.
    /// - Throws: `FirestoreError` for a non-200 response, or a `DecodingError` if the stored
    ///   fields do not fit the type.
    public func getDocument<T: Decodable>(
        _ reference: DocumentReference,
        as type: T.Type
    ) async throws -> T {
        let document = try await getDocument(reference)
        let decoder = FirestoreDecoder(keyDecodingStrategy: configuration.keyDecodingStrategy)
        return try decoder.decode(type, from: document)
    }

    /// Reads a document without decoding it, keeping its Firestore-typed values.
    ///
    /// Sends `GET` to the document's REST resource name. Use it when the field types are not
    /// known ahead of time, or to reach `createTime` and `updateTime`.
    ///
    /// - Throws: `FirestoreError` built from the HTTP status — HTTP 404 becomes
    ///   `.api(.notFound)`, so reading a document that does not exist throws.
    public func getDocument(_ reference: DocumentReference) async throws -> FirestoreDocument {
        let url = "\(configuration.baseURL)/\(reference.restName)"

        var request = HTTPClientRequest(url: url)
        request.method = .GET
        request.headers.add(name: "Authorization", value: "Bearer \(token)")
        request.headers.add(name: "Content-Type", value: "application/json")

        let response = try await client.execute(request, timeout: .seconds(Int64(configuration.timeout)))
        let body = try await response.body.collect(upTo: 10 * 1024 * 1024)

        guard response.status == .ok else {
            throw FirestoreError.fromHTTPResponse(
                statusCode: Int(response.status.code),
                body: body.toData(),
                path: reference.path.rawValue
            )
        }

        let json = try JSONSerialization.jsonObject(with: body.toData()) as? [String: Any] ?? [:]
        return try FirestoreDocument.fromJSON(json)
    }

    // MARK: - Create Document

    /// Encodes a value and creates it as a new document, failing if one is already there.
    ///
    /// - Parameters:
    ///   - reference: Where the document should be created. Its ID is taken from the last path
    ///     segment, so Firestore does not generate one.
    ///   - data: The value to encode into the document's fields.
    /// - Throws: `FirestoreError.api(.alreadyExists)` when a document with that ID already
    ///   exists — use `updateDocument(_:data:)` to overwrite instead.
    public func createDocument<T: Encodable>(
        _ reference: DocumentReference,
        data: T
    ) async throws {
        let encoder = FirestoreEncoder(keyEncodingStrategy: configuration.keyEncodingStrategy)
        let fields = try encoder.encode(data)
        try await createDocument(reference, fields: fields)
    }

    /// Creates a document from Firestore-typed fields, failing if one is already there.
    ///
    /// Sends `POST` to the parent collection with `?documentId=`, the REST `createDocument`
    /// method, so the server refuses the write when that ID is taken and answers HTTP 409.
    /// That refusal is the only exclusion guarantee here — there is no read-then-write check to
    /// race with.
    ///
    /// - Important: The document ID goes into the query string as it is, without
    ///   percent-encoding; an ID containing `&`, `#`, or `?` will not arrive intact.
    public func createDocument(
        _ reference: DocumentReference,
        fields: [String: FirestoreValue]
    ) async throws {
        let parentCollection = reference.parent
        let documentId = reference.documentId

        let url = "\(configuration.baseURL)/\(parentCollection.restParent)/\(parentCollection.restCollectionId)?documentId=\(documentId)"

        var fieldsJSON: [String: Any] = [:]
        for (key, value) in fields {
            fieldsJSON[key] = value.toJSON()
        }
        let bodyJSON: [String: Any] = ["fields": fieldsJSON]
        let bodyData = try JSONSerialization.data(withJSONObject: bodyJSON)

        var request = HTTPClientRequest(url: url)
        request.method = .POST
        request.headers.add(name: "Authorization", value: "Bearer \(token)")
        request.headers.add(name: "Content-Type", value: "application/json")
        request.body = .bytes(ByteBuffer(data: bodyData))

        let response = try await client.execute(request, timeout: .seconds(Int64(configuration.timeout)))
        let body = try await response.body.collect(upTo: 10 * 1024 * 1024)

        guard response.status == .ok else {
            throw FirestoreError.fromHTTPResponse(
                statusCode: Int(response.status.code),
                body: body.toData(),
                path: reference.path.rawValue
            )
        }
    }

    // MARK: - Update Document

    /// Encodes a value and writes it over the document, replacing everything it held.
    ///
    /// The encoded value becomes the whole document: any field the type does not produce is
    /// dropped from the stored document. Sending a partial struct therefore deletes the rest.
    ///
    /// - Parameters:
    ///   - reference: The document to write.
    ///   - data: The value that becomes the document's complete set of fields.
    public func updateDocument<T: Encodable>(
        _ reference: DocumentReference,
        data: T
    ) async throws {
        let encoder = FirestoreEncoder(keyEncodingStrategy: configuration.keyEncodingStrategy)
        let fields = try encoder.encode(data)
        try await updateDocument(reference, fields: fields)
    }

    /// Writes Firestore-typed fields over the document, replacing everything it held.
    ///
    /// Sends `PATCH` to the document's REST resource name with no `updateMask` and no
    /// `currentDocument` precondition, which gives set-without-merge semantics:
    ///
    /// - Fields absent from `fields` are removed from the stored document, because no mask tells
    ///   the server which fields to leave alone. To keep them, read the document first and send
    ///   the merged map.
    /// - The document is created if it does not exist yet, because nothing asserts that it does.
    /// - Concurrent writers are not serialised, so the request that reaches Firestore last wins
    ///   and overwrites whatever the other one wrote.
    public func updateDocument(
        _ reference: DocumentReference,
        fields: [String: FirestoreValue]
    ) async throws {
        let url = "\(configuration.baseURL)/\(reference.restName)"

        var fieldsJSON: [String: Any] = [:]
        for (key, value) in fields {
            fieldsJSON[key] = value.toJSON()
        }
        let bodyJSON: [String: Any] = ["fields": fieldsJSON]
        let bodyData = try JSONSerialization.data(withJSONObject: bodyJSON)

        var request = HTTPClientRequest(url: url)
        request.method = .PATCH
        request.headers.add(name: "Authorization", value: "Bearer \(token)")
        request.headers.add(name: "Content-Type", value: "application/json")
        request.body = .bytes(ByteBuffer(data: bodyData))

        let response = try await client.execute(request, timeout: .seconds(Int64(configuration.timeout)))
        let body = try await response.body.collect(upTo: 10 * 1024 * 1024)

        guard response.status == .ok else {
            throw FirestoreError.fromHTTPResponse(
                statusCode: Int(response.status.code),
                body: body.toData(),
                path: reference.path.rawValue
            )
        }
    }

    // MARK: - Delete Document

    /// Deletes a document.
    ///
    /// Sends `DELETE` to the document's REST resource name with no `currentDocument`
    /// precondition, so nothing here asserts that the document was there in the first place.
    /// Documents in its subcollections are left where they are and stay reachable by path —
    /// delete them yourself if they should go.
    public func deleteDocument(_ reference: DocumentReference) async throws {
        let url = "\(configuration.baseURL)/\(reference.restName)"

        var request = HTTPClientRequest(url: url)
        request.method = .DELETE
        request.headers.add(name: "Authorization", value: "Bearer \(token)")

        let response = try await client.execute(request, timeout: .seconds(Int64(configuration.timeout)))
        let body = try await response.body.collect(upTo: 10 * 1024 * 1024)

        guard response.status == .ok else {
            throw FirestoreError.fromHTTPResponse(
                statusCode: Int(response.status.code),
                body: body.toData(),
                path: reference.path.rawValue
            )
        }
    }

    // MARK: - List Documents

    /// Reads one page of documents from a collection and decodes each one.
    ///
    /// Every document in the page must decode, so a single stray document fails the whole call.
    ///
    /// - Parameters:
    ///   - collection: The collection to list.
    ///   - type: The type each document is decoded into.
    ///   - pageSize: How many documents to ask for in this page.
    ///   - pageToken: The token from the previous page, or `nil` to start at the first one.
    /// - Returns: The page's documents, and the token for the next page — `nil` once the last
    ///   page has been read.
    public func listDocuments<T: Decodable>(
        in collection: CollectionReference,
        as type: T.Type,
        pageSize: Int = 100,
        pageToken: String? = nil
    ) async throws -> (documents: [T], nextPageToken: String?) {
        let (documents, nextToken) = try await listDocuments(
            in: collection,
            pageSize: pageSize,
            pageToken: pageToken
        )

        let decoder = FirestoreDecoder(keyDecodingStrategy: configuration.keyDecodingStrategy)
        let decoded = try documents.map { try decoder.decode(type, from: $0) }
        return (decoded, nextToken)
    }

    /// Reads one page of documents from a collection without decoding them.
    ///
    /// Sends `GET` to the parent plus the collection ID, the REST `listDocuments` method, which
    /// lists the documents directly in that collection and nothing from its subcollections. It
    /// applies no filter and no ordering of its own: use a query for those.
    ///
    /// An empty collection yields an empty array and a `nil` token rather than an error, so
    /// listing something that is not there and listing something empty look the same. Paging is
    /// the caller's job — feed the returned token back in until it comes out `nil`.
    ///
    /// - Note: The whole page has to fit in the 10 MiB the client reads from one response.
    public func listDocuments(
        in collection: CollectionReference,
        pageSize: Int = 100,
        pageToken: String? = nil
    ) async throws -> (documents: [FirestoreDocument], nextPageToken: String?) {
        var urlString = "\(configuration.baseURL)/\(collection.restParent)/\(collection.restCollectionId)?pageSize=\(pageSize)"
        if let pageToken {
            urlString += "&pageToken=\(pageToken)"
        }

        var request = HTTPClientRequest(url: urlString)
        request.method = .GET
        request.headers.add(name: "Authorization", value: "Bearer \(token)")
        request.headers.add(name: "Content-Type", value: "application/json")

        let response = try await client.execute(request, timeout: .seconds(Int64(configuration.timeout)))
        let body = try await response.body.collect(upTo: 10 * 1024 * 1024)

        guard response.status == .ok else {
            throw FirestoreError.fromHTTPResponse(
                statusCode: Int(response.status.code),
                body: body.toData(),
                path: collection.path.rawValue
            )
        }

        let json = try JSONSerialization.jsonObject(with: body.toData()) as? [String: Any] ?? [:]

        var documents: [FirestoreDocument] = []
        if let documentsJSON = json["documents"] as? [[String: Any]] {
            for docJSON in documentsJSON {
                documents.append(try FirestoreDocument.fromJSON(docJSON))
            }
        }

        let nextToken = json["nextPageToken"] as? String
        return (documents, nextToken)
    }
}
