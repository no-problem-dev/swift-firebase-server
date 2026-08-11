import AsyncHTTPClient
import Foundation
import Internal
import NIOCore
import NIOHTTP1

// MARK: - Query Operations

extension FirestoreClient {
    /// Runs a query and decodes every matching document.
    ///
    /// No match returns an empty array; it is not an error. Every returned document must decode,
    /// so one document that does not fit the type fails the whole call with
    /// `FirestoreError.decoding` — narrow the query or use `runQueryRaw(_:)` when a collection
    /// holds mixed shapes.
    public func runQuery<T: Decodable & Sendable>(_ query: Query<T>) async throws -> [T] {
        let documents = try await runQueryRaw(query)
        return try documents.map { try decode(T.self, from: $0) }
    }

    /// Runs a query and returns the matching documents undecoded.
    ///
    /// Sends `POST …:runQuery` to the collection's parent, carrying the built `structuredQuery`.
    /// Firestore answers with a stream of partial results, some of which carry only a read time
    /// or a skipped count; those are dropped, so a query that matches nothing comes back as an
    /// empty array. The request names no transaction and no read time, so it reads the database
    /// as of whenever the server handled it, and two queries in a row can disagree.
    ///
    /// - Note: The whole result has to fit in the 10 MiB the client reads from one response, and
    ///   the results arrive in one piece rather than page by page. Bound large queries with
    ///   `limit(to:)` and a cursor.
    public func runQueryRaw<T>(_ query: Query<T>) async throws -> [FirestoreDocument] {
        let url = "\(configuration.baseURL)/\(query.collection.restParent):runQuery"

        let requestBody: [String: Any] = [
            "structuredQuery": query.buildStructuredQuery()
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)

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
                path: query.collection.path.rawValue
            )
        }

        guard let results = try JSONSerialization.jsonObject(with: body.toData()) as? [[String: Any]] else {
            return []
        }

        var documents: [FirestoreDocument] = []
        for result in results {
            if let docJSON = result["document"] as? [String: Any] {
                documents.append(try FirestoreDocument.fromJSON(docJSON))
            }
        }

        return documents
    }

    /// Builds a query over a collection and runs it in one step.
    ///
    /// ```swift
    /// let recent = try await firestore.query(booksRef, as: Book.self) { query in
    ///     query.order(by: Book.Fields.updatedAt, direction: .descending).limit(to: 20)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - collection: The collection to query.
    ///   - type: The type each matching document is decoded into.
    ///   - configure: Adds filters, ordering, cursors, and limits to the empty query it is
    ///     handed. Each builder call returns a new query, so return the result of the chain.
    public func query<T: Decodable & Sendable>(
        _ collection: CollectionReference,
        as type: T.Type,
        configure: (Query<T>) -> Query<T>
    ) async throws -> [T] {
        let query = configure(collection.query(as: type))
        return try await runQuery(query)
    }
}
