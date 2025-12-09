import AsyncHTTPClient
import Foundation
import NIOCore
import NIOHTTP1

// MARK: - Document Operations

extension FirestoreClient {
    // MARK: - Get Document

    /// ドキュメントを取得
    /// - Parameters:
    ///   - reference: ドキュメント参照
    ///   - authorization: Firebase ID Token
    /// - Returns: デコードされたドキュメント
    public func getDocument<T: Decodable>(
        _ reference: DocumentReference,
        as type: T.Type,
        authorization: String
    ) async throws -> T {
        let document = try await getDocument(reference, authorization: authorization)
        let decoder = FirestoreDecoder()
        return try decoder.decode(type, from: document)
    }

    /// ドキュメントを取得（生のFirestoreDocument）
    /// - Parameters:
    ///   - reference: ドキュメント参照
    ///   - authorization: Firebase ID Token
    /// - Returns: FirestoreDocument
    public func getDocument(
        _ reference: DocumentReference,
        authorization: String
    ) async throws -> FirestoreDocument {
        let url = "\(configuration.baseURL)/\(reference.restName)"

        var request = HTTPClientRequest(url: url)
        request.method = .GET
        request.headers.add(name: "Authorization", value: "Bearer \(authorization)")
        request.headers.add(name: "Content-Type", value: "application/json")

        let response = try await client.execute(request, timeout: .seconds(Int64(configuration.timeout)))
        let body = try await response.body.collect(upTo: 10 * 1024 * 1024) // 10MB limit

        guard response.status == .ok else {
            throw FirestoreError.fromHTTPResponse(
                statusCode: Int(response.status.code),
                body: Data(buffer: body),
                path: reference.path.rawValue
            )
        }

        let json = try JSONSerialization.jsonObject(with: Data(buffer: body)) as? [String: Any] ?? [:]
        return try FirestoreDocument.fromJSON(json)
    }

    // MARK: - Create Document

    /// ドキュメントを作成（ID指定）
    /// - Parameters:
    ///   - reference: ドキュメント参照
    ///   - data: 保存するデータ
    ///   - authorization: Firebase ID Token
    public func createDocument<T: Encodable>(
        _ reference: DocumentReference,
        data: T,
        authorization: String
    ) async throws {
        let encoder = FirestoreEncoder()
        let fields = try encoder.encode(data)
        try await createDocument(reference, fields: fields, authorization: authorization)
    }

    /// ドキュメントを作成（フィールド直接指定）
    /// - Parameters:
    ///   - reference: ドキュメント参照
    ///   - fields: フィールドマップ
    ///   - authorization: Firebase ID Token
    public func createDocument(
        _ reference: DocumentReference,
        fields: [String: FirestoreValue],
        authorization: String
    ) async throws {
        // createDocument APIは parent と collectionId を使う
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
        request.headers.add(name: "Authorization", value: "Bearer \(authorization)")
        request.headers.add(name: "Content-Type", value: "application/json")
        request.body = .bytes(ByteBuffer(data: bodyData))

        let response = try await client.execute(request, timeout: .seconds(Int64(configuration.timeout)))
        let body = try await response.body.collect(upTo: 10 * 1024 * 1024)

        guard response.status == .ok else {
            throw FirestoreError.fromHTTPResponse(
                statusCode: Int(response.status.code),
                body: Data(buffer: body),
                path: reference.path.rawValue
            )
        }
    }

    // MARK: - Update Document (Patch)

    /// ドキュメントを更新
    /// - Parameters:
    ///   - reference: ドキュメント参照
    ///   - data: 更新するデータ
    ///   - authorization: Firebase ID Token
    public func updateDocument<T: Encodable>(
        _ reference: DocumentReference,
        data: T,
        authorization: String
    ) async throws {
        let encoder = FirestoreEncoder()
        let fields = try encoder.encode(data)
        try await updateDocument(reference, fields: fields, authorization: authorization)
    }

    /// ドキュメントを更新（フィールド直接指定）
    /// - Parameters:
    ///   - reference: ドキュメント参照
    ///   - fields: フィールドマップ
    ///   - authorization: Firebase ID Token
    public func updateDocument(
        _ reference: DocumentReference,
        fields: [String: FirestoreValue],
        authorization: String
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
        request.headers.add(name: "Authorization", value: "Bearer \(authorization)")
        request.headers.add(name: "Content-Type", value: "application/json")
        request.body = .bytes(ByteBuffer(data: bodyData))

        let response = try await client.execute(request, timeout: .seconds(Int64(configuration.timeout)))
        let body = try await response.body.collect(upTo: 10 * 1024 * 1024)

        guard response.status == .ok else {
            throw FirestoreError.fromHTTPResponse(
                statusCode: Int(response.status.code),
                body: Data(buffer: body),
                path: reference.path.rawValue
            )
        }
    }

    // MARK: - Delete Document

    /// ドキュメントを削除
    /// - Parameters:
    ///   - reference: ドキュメント参照
    ///   - authorization: Firebase ID Token
    public func deleteDocument(
        _ reference: DocumentReference,
        authorization: String
    ) async throws {
        let url = "\(configuration.baseURL)/\(reference.restName)"

        var request = HTTPClientRequest(url: url)
        request.method = .DELETE
        request.headers.add(name: "Authorization", value: "Bearer \(authorization)")

        let response = try await client.execute(request, timeout: .seconds(Int64(configuration.timeout)))
        let body = try await response.body.collect(upTo: 10 * 1024 * 1024)

        guard response.status == .ok else {
            throw FirestoreError.fromHTTPResponse(
                statusCode: Int(response.status.code),
                body: Data(buffer: body),
                path: reference.path.rawValue
            )
        }
    }

    // MARK: - List Documents

    /// コレクション内のドキュメント一覧を取得
    /// - Parameters:
    ///   - collection: コレクション参照
    ///   - authorization: Firebase ID Token
    ///   - pageSize: 1ページあたりの件数（デフォルト: 100）
    ///   - pageToken: ページネーショントークン
    /// - Returns: ドキュメント配列とページネーショントークン
    public func listDocuments<T: Decodable>(
        in collection: CollectionReference,
        as type: T.Type,
        authorization: String,
        pageSize: Int = 100,
        pageToken: String? = nil
    ) async throws -> (documents: [T], nextPageToken: String?) {
        let (documents, token) = try await listDocuments(
            in: collection,
            authorization: authorization,
            pageSize: pageSize,
            pageToken: pageToken
        )

        let decoder = FirestoreDecoder()
        let decoded = try documents.map { try decoder.decode(type, from: $0) }
        return (decoded, token)
    }

    /// コレクション内のドキュメント一覧を取得（生のFirestoreDocument）
    public func listDocuments(
        in collection: CollectionReference,
        authorization: String,
        pageSize: Int = 100,
        pageToken: String? = nil
    ) async throws -> (documents: [FirestoreDocument], nextPageToken: String?) {
        var urlString = "\(configuration.baseURL)/\(collection.restParent)/\(collection.restCollectionId)?pageSize=\(pageSize)"
        if let token = pageToken {
            urlString += "&pageToken=\(token)"
        }

        var request = HTTPClientRequest(url: urlString)
        request.method = .GET
        request.headers.add(name: "Authorization", value: "Bearer \(authorization)")
        request.headers.add(name: "Content-Type", value: "application/json")

        let response = try await client.execute(request, timeout: .seconds(Int64(configuration.timeout)))
        let body = try await response.body.collect(upTo: 10 * 1024 * 1024)

        guard response.status == .ok else {
            throw FirestoreError.fromHTTPResponse(
                statusCode: Int(response.status.code),
                body: Data(buffer: body),
                path: collection.path.rawValue
            )
        }

        let json = try JSONSerialization.jsonObject(with: Data(buffer: body)) as? [String: Any] ?? [:]

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
