import AsyncHTTPClient
import Foundation
import Internal
import NIOCore
import NIOHTTP1

// MARK: - Document Operations

extension FirestoreClient {
    // MARK: - Get Document

    /// ドキュメントを取得
    public func getDocument<T: Decodable>(
        _ reference: DocumentReference,
        as type: T.Type
    ) async throws -> T {
        let document = try await getDocument(reference)
        let decoder = FirestoreDecoder(keyDecodingStrategy: configuration.keyDecodingStrategy)
        return try decoder.decode(type, from: document)
    }

    /// ドキュメントを取得（生のFirestoreDocument）
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

    /// ドキュメントを作成
    public func createDocument<T: Encodable>(
        _ reference: DocumentReference,
        data: T
    ) async throws {
        let encoder = FirestoreEncoder(keyEncodingStrategy: configuration.keyEncodingStrategy)
        let fields = try encoder.encode(data)
        try await createDocument(reference, fields: fields)
    }

    /// ドキュメントを作成（フィールド直接指定）
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

    /// ドキュメントを更新
    public func updateDocument<T: Encodable>(
        _ reference: DocumentReference,
        data: T
    ) async throws {
        let encoder = FirestoreEncoder(keyEncodingStrategy: configuration.keyEncodingStrategy)
        let fields = try encoder.encode(data)
        try await updateDocument(reference, fields: fields)
    }

    /// ドキュメントを更新（フィールド直接指定）
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

    /// ドキュメントを削除
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

    /// コレクション内のドキュメント一覧を取得
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

    /// コレクション内のドキュメント一覧を取得（生のFirestoreDocument）
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
