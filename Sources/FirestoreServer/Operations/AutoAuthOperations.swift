import Foundation
import Internal

// MARK: - Auto-Authenticated Document Operations

extension FirestoreClient {
    // MARK: - Get Document (Auto Auth)

    /// ドキュメントを取得（サービスアカウント認証を自動使用）
    ///
    /// Cloud Run 環境ではメタデータサーバーから、
    /// ローカル環境では gcloud CLI からアクセストークンを自動取得する。
    ///
    /// - Parameters:
    ///   - reference: ドキュメント参照
    ///   - type: デコード先の型
    /// - Returns: デコードされたドキュメント
    /// - Throws: `FirestoreError` または `GCPAuthError`
    public func getDocument<T: Decodable>(
        _ reference: DocumentReference,
        as type: T.Type
    ) async throws -> T {
        let token = try await AccessTokenProvider.shared.getAccessToken()
        return try await getDocument(reference, as: type, authorization: token)
    }

    /// ドキュメントを取得（サービスアカウント認証を自動使用、生のFirestoreDocument）
    ///
    /// - Parameter reference: ドキュメント参照
    /// - Returns: FirestoreDocument
    /// - Throws: `FirestoreError` または `GCPAuthError`
    public func getDocument(_ reference: DocumentReference) async throws -> FirestoreDocument {
        let token = try await AccessTokenProvider.shared.getAccessToken()
        return try await getDocument(reference, authorization: token)
    }

    // MARK: - Create Document (Auto Auth)

    /// ドキュメントを作成（サービスアカウント認証を自動使用）
    ///
    /// - Parameters:
    ///   - reference: ドキュメント参照
    ///   - data: 保存するデータ
    /// - Throws: `FirestoreError` または `GCPAuthError`
    public func createDocument<T: Encodable>(
        _ reference: DocumentReference,
        data: T
    ) async throws {
        let token = try await AccessTokenProvider.shared.getAccessToken()
        try await createDocument(reference, data: data, authorization: token)
    }

    /// ドキュメントを作成（サービスアカウント認証を自動使用、フィールド直接指定）
    ///
    /// - Parameters:
    ///   - reference: ドキュメント参照
    ///   - fields: フィールドマップ
    /// - Throws: `FirestoreError` または `GCPAuthError`
    public func createDocument(
        _ reference: DocumentReference,
        fields: [String: FirestoreValue]
    ) async throws {
        let token = try await AccessTokenProvider.shared.getAccessToken()
        try await createDocument(reference, fields: fields, authorization: token)
    }

    // MARK: - Update Document (Auto Auth)

    /// ドキュメントを更新（サービスアカウント認証を自動使用）
    ///
    /// - Parameters:
    ///   - reference: ドキュメント参照
    ///   - data: 更新するデータ
    /// - Throws: `FirestoreError` または `GCPAuthError`
    public func updateDocument<T: Encodable>(
        _ reference: DocumentReference,
        data: T
    ) async throws {
        let token = try await AccessTokenProvider.shared.getAccessToken()
        try await updateDocument(reference, data: data, authorization: token)
    }

    /// ドキュメントを更新（サービスアカウント認証を自動使用、フィールド直接指定）
    ///
    /// - Parameters:
    ///   - reference: ドキュメント参照
    ///   - fields: フィールドマップ
    /// - Throws: `FirestoreError` または `GCPAuthError`
    public func updateDocument(
        _ reference: DocumentReference,
        fields: [String: FirestoreValue]
    ) async throws {
        let token = try await AccessTokenProvider.shared.getAccessToken()
        try await updateDocument(reference, fields: fields, authorization: token)
    }

    // MARK: - Delete Document (Auto Auth)

    /// ドキュメントを削除（サービスアカウント認証を自動使用）
    ///
    /// - Parameter reference: ドキュメント参照
    /// - Throws: `FirestoreError` または `GCPAuthError`
    public func deleteDocument(_ reference: DocumentReference) async throws {
        let token = try await AccessTokenProvider.shared.getAccessToken()
        try await deleteDocument(reference, authorization: token)
    }

    // MARK: - List Documents (Auto Auth)

    /// コレクション内のドキュメント一覧を取得（サービスアカウント認証を自動使用）
    ///
    /// - Parameters:
    ///   - collection: コレクション参照
    ///   - type: デコード先の型
    ///   - pageSize: 1ページあたりの件数（デフォルト: 100）
    ///   - pageToken: ページネーショントークン
    /// - Returns: ドキュメント配列とページネーショントークン
    /// - Throws: `FirestoreError` または `GCPAuthError`
    public func listDocuments<T: Decodable>(
        in collection: CollectionReference,
        as type: T.Type,
        pageSize: Int = 100,
        pageToken: String? = nil
    ) async throws -> (documents: [T], nextPageToken: String?) {
        let token = try await AccessTokenProvider.shared.getAccessToken()
        return try await listDocuments(
            in: collection,
            as: type,
            authorization: token,
            pageSize: pageSize,
            pageToken: pageToken
        )
    }

    /// コレクション内のドキュメント一覧を取得（サービスアカウント認証を自動使用、生のFirestoreDocument）
    ///
    /// - Parameters:
    ///   - collection: コレクション参照
    ///   - pageSize: 1ページあたりの件数（デフォルト: 100）
    ///   - pageToken: ページネーショントークン
    /// - Returns: ドキュメント配列とページネーショントークン
    /// - Throws: `FirestoreError` または `GCPAuthError`
    public func listDocuments(
        in collection: CollectionReference,
        pageSize: Int = 100,
        pageToken: String? = nil
    ) async throws -> (documents: [FirestoreDocument], nextPageToken: String?) {
        let token = try await AccessTokenProvider.shared.getAccessToken()
        return try await listDocuments(
            in: collection,
            authorization: token,
            pageSize: pageSize,
            pageToken: pageToken
        )
    }

    // MARK: - Query Operations (Auto Auth)

    /// クエリを実行してドキュメントを取得（サービスアカウント認証を自動使用）
    ///
    /// - Parameter query: 実行するクエリ
    /// - Returns: デコードされたドキュメント配列
    /// - Throws: `FirestoreError` または `GCPAuthError`
    public func runQuery<T: Decodable & Sendable>(_ query: Query<T>) async throws -> [T] {
        let token = try await AccessTokenProvider.shared.getAccessToken()
        return try await runQuery(query, authorization: token)
    }

    /// クエリを実行してFirestoreDocumentを取得（サービスアカウント認証を自動使用）
    ///
    /// - Parameter query: 実行するクエリ
    /// - Returns: FirestoreDocument配列
    /// - Throws: `FirestoreError` または `GCPAuthError`
    public func runQueryRaw<T>(_ query: Query<T>) async throws -> [FirestoreDocument] {
        let token = try await AccessTokenProvider.shared.getAccessToken()
        return try await runQueryRaw(query, authorization: token)
    }

    /// コレクションに対するクエリを実行（サービスアカウント認証を自動使用）
    ///
    /// - Parameters:
    ///   - collection: コレクション参照
    ///   - type: 結果のデコード型
    ///   - configure: クエリ設定クロージャ
    /// - Returns: デコードされたドキュメント配列
    /// - Throws: `FirestoreError` または `GCPAuthError`
    public func query<T: Decodable & Sendable>(
        _ collection: CollectionReference,
        as type: T.Type,
        configure: (Query<T>) -> Query<T>
    ) async throws -> [T] {
        let token = try await AccessTokenProvider.shared.getAccessToken()
        return try await query(collection, as: type, authorization: token, configure: configure)
    }
}
