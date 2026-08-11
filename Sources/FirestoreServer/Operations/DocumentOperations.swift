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
    /// - Throws: `FirestoreError.api` for a non-200 response, or `FirestoreError.decoding` wrapping
    ///   the `DecodingError` if the stored fields do not fit the type.
    public func getDocument<T: Decodable>(
        _ reference: DocumentReference,
        as type: T.Type
    ) async throws -> T {
        let document = try await getDocument(reference)
        return try decode(type, from: document)
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
    ///   exists — use ``setDocument(_:data:)`` to overwrite instead.
    public func createDocument<T: Encodable>(
        _ reference: DocumentReference,
        data: T
    ) async throws {
        try await createDocument(reference, fields: try encodeFields(data))
    }

    /// Creates a document from Firestore-typed fields, failing if one is already there.
    ///
    /// Sends `POST` to the parent collection with `?documentId=`, the REST `createDocument`
    /// method, so the server refuses the write when that ID is taken and answers HTTP 409.
    /// That refusal is the only exclusion guarantee here — there is no read-then-write check to
    /// race with.
    ///
    /// The document ID is percent-encoded into the query string, so an ID holding `&`, `#`, or `?`
    /// arrives as the ID you passed.
    public func createDocument(
        _ reference: DocumentReference,
        fields: [String: FirestoreValue]
    ) async throws {
        let parentCollection = reference.parent
        let documentId = reference.documentId

        let url = "\(configuration.baseURL)/\(parentCollection.restParent)/\(parentCollection.restCollectionId)?documentId=\(Self.queryEncoded(documentId))"

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

    // MARK: - Set Document

    /// Encodes a value and writes it over the document, replacing everything it held.
    ///
    /// The encoded value becomes the whole document: any field the type does not produce is
    /// dropped from the stored document. Use ``updateDocument(_:data:)`` to change some fields and
    /// leave the rest alone.
    ///
    /// - Parameters:
    ///   - reference: The document to write.
    ///   - data: The value that becomes the document's complete set of fields.
    public func setDocument<T: Encodable>(
        _ reference: DocumentReference,
        data: T
    ) async throws {
        try await setDocument(reference, fields: try encodeFields(data))
    }

    /// Writes Firestore-typed fields over the document, replacing everything it held.
    ///
    /// Sends `PATCH` to the document's REST resource name with no `updateMask` and no
    /// `currentDocument` precondition, which is what the REST API calls a write of the whole
    /// document:
    ///
    /// - Fields absent from `fields` are removed from the stored document, because no mask tells
    ///   the server which fields to leave alone.
    /// - The document is created if it does not exist yet, because nothing asserts that it does.
    /// - Concurrent writers are not serialised, so the request that reaches Firestore last wins
    ///   and overwrites whatever the other one wrote.
    public func setDocument(
        _ reference: DocumentReference,
        fields: [String: FirestoreValue]
    ) async throws {
        try await patchDocument(reference, fields: fields, updateMask: nil, requireExists: false)
    }

    // MARK: - Update Document

    /// Encodes a value and changes only the fields it produces, leaving the rest of the document
    /// alone.
    ///
    /// The encoded field names become the `updateMask`, so a partial struct updates its own fields
    /// and nothing else. The document has to exist: the write carries `currentDocument.exists`, so
    /// a missing document fails with `FirestoreError.api(.notFound)` instead of being created. Use
    /// ``setDocument(_:data:)`` when the value is meant to become the whole document.
    ///
    /// - Parameters:
    ///   - reference: The document to update.
    ///   - data: The value whose fields are written. Its field names, and only those, are updated.
    /// - Throws: `FirestoreError.api(.invalidArgument)` if the value encodes to no fields at all,
    ///   since an empty mask would ask Firestore to replace the document.
    public func updateDocument<T: Encodable>(
        _ reference: DocumentReference,
        data: T
    ) async throws {
        try await updateDocument(reference, fields: try encodeFields(data))
    }

    /// Changes only the given fields, leaving the rest of the document alone.
    ///
    /// Sends `PATCH` with `updateMask.fieldPaths` naming exactly the keys of `fields`, and
    /// `currentDocument.exists=true`:
    ///
    /// - A field the stored document holds but `fields` does not is left where it is.
    /// - A field named in `fields` is written, whether or not the document already had it.
    /// - A document that does not exist is not created; the API answers HTTP 404.
    ///
    /// Each key is a top-level field name, so writing a map field replaces that whole map rather
    /// than merging into it.
    ///
    /// - Throws: `FirestoreError.api(.invalidArgument)` for an empty `fields`, which would
    ///   otherwise send a maskless write and replace the document.
    public func updateDocument(
        _ reference: DocumentReference,
        fields: [String: FirestoreValue]
    ) async throws {
        guard !fields.isEmpty else {
            throw FirestoreError.invalidArgument(
                message: "updateDocument requires at least one field; an empty update would replace the document at \(reference.path.rawValue)"
            )
        }

        try await patchDocument(
            reference,
            fields: fields,
            updateMask: fields.keys.sorted(),
            requireExists: true
        )
    }

    // MARK: - Patch

    /// Sends one `PATCH` to a document's REST resource name.
    ///
    /// - Parameters:
    ///   - updateMask: The field paths the write is restricted to, or `nil` to write the whole
    ///     document. Firestore leaves unmasked fields unchanged, and deletes masked fields that the
    ///     body does not carry.
    ///   - requireExists: Whether to send `currentDocument.exists=true`, which turns a write to a
    ///     missing document into HTTP 404 rather than a create.
    private func patchDocument(
        _ reference: DocumentReference,
        fields: [String: FirestoreValue],
        updateMask: [String]?,
        requireExists: Bool
    ) async throws {
        var url = "\(configuration.baseURL)/\(reference.restName)"

        var queryItems: [String] = []
        for fieldName in updateMask ?? [] {
            queryItems.append("updateMask.fieldPaths=\(Self.queryEncoded(FieldPathSyntax.quoted(fieldName)))")
        }
        if requireExists {
            queryItems.append("currentDocument.exists=true")
        }
        if !queryItems.isEmpty {
            url += "?\(queryItems.joined(separator: "&"))"
        }

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

    /// Percent-encodes a query value, escaping everything outside RFC 3986's unreserved set.
    static func queryEncoded(_ value: String) -> String {
        let unreserved = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        )
        return value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? value
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

        let decoded = try documents.map { try decode(type, from: $0) }
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
            urlString += "&pageToken=\(Self.queryEncoded(pageToken))"
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

    // MARK: - Coding

    /// Encodes a value into document fields, reporting a failure as a `FirestoreError`.
    ///
    /// - Throws: `FirestoreError.encoding` wrapping whatever the encoder raised, so a caller can
    ///   catch one error type for everything a write can fail with.
    func encodeFields<T: Encodable>(_ value: T) throws -> [String: FirestoreValue] {
        let encoder = FirestoreEncoder(keyEncodingStrategy: configuration.keyEncodingStrategy)
        do {
            return try encoder.encode(value)
        } catch {
            throw FirestoreError.encoding(underlying: error)
        }
    }

    /// Decodes a stored document into a value, reporting a failure as a `FirestoreError`.
    ///
    /// - Throws: `FirestoreError.decoding` wrapping the `DecodingError`, so a document that does
    ///   not fit the type fails the same way as everything else a read can fail with.
    func decode<T: Decodable>(_ type: T.Type, from document: FirestoreDocument) throws -> T {
        let decoder = FirestoreDecoder(keyDecodingStrategy: configuration.keyDecodingStrategy)
        do {
            return try decoder.decode(type, from: document)
        } catch {
            throw FirestoreError.decoding(underlying: error)
        }
    }
}
