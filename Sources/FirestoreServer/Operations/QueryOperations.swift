import AsyncHTTPClient
import Foundation
import Internal
import NIOCore
import NIOHTTP1

// MARK: - Query Operations

extension FirestoreClient {
    /// クエリを実行してドキュメントを取得
    public func runQuery<T: Decodable & Sendable>(_ query: Query<T>) async throws -> [T] {
        let documents = try await runQueryRaw(query)
        let decoder = FirestoreDecoder(keyDecodingStrategy: configuration.keyDecodingStrategy)
        return try documents.map { try decoder.decode(T.self, from: $0) }
    }

    /// クエリを実行してFirestoreDocumentを取得
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

    /// コレクションに対するクエリを実行
    public func query<T: Decodable & Sendable>(
        _ collection: CollectionReference,
        as type: T.Type,
        configure: (Query<T>) -> Query<T>
    ) async throws -> [T] {
        let query = configure(collection.query(as: type))
        return try await runQuery(query)
    }
}
