import Foundation

/// クライアントが使用するトークン取得戦略
///
/// `FirestoreClient` や `StorageClient` など、長期的に保持されるクライアントから
/// リクエストごとに最新トークンを取得するための分岐型。
///
/// - `dynamic`: `.auto` / `.autoWithDatabase` で作成したクライアント向け。
///   `GCPEnvironment.shared.getAccessToken()` を呼び、cache の自動更新に追従する。
/// - `emulator`: Firebase Emulator Suite 使用時。ダミー "owner" トークンを返す。
/// - `staticToken`: `.explicit(projectId:token:)` でユーザーが明示的に指定した
///   トークンをそのまま使用する（テスト・カスタム認証フロー用）。
public enum TokenSource: Sendable {
    case dynamic
    case emulator
    case staticToken(String)

    /// `GCPConfiguration` から対応する `TokenSource` を構築
    ///
    /// - Parameters:
    ///   - config: 元の設定
    ///   - resolvedToken: `.auto` 解決時に取得した初期トークン（`.explicit` では未使用）
    public init(config: GCPConfiguration, resolvedToken: String) {
        switch config {
        case .auto, .autoWithDatabase:
            self = .dynamic
        case .emulator:
            self = .emulator
        case .explicit(_, let token):
            self = .staticToken(token)
        }
    }

    /// このトークンソースから最新のアクセストークンを取得
    ///
    /// - Returns: `Authorization: Bearer {token}` ヘッダーに使用するトークン
    /// - Throws: `GCPAuthError` metadata server / gcloud CLI 取得に失敗した場合
    public func currentToken() async throws -> String {
        switch self {
        case .dynamic:
            return try await GCPEnvironment.shared.getAccessToken()
        case .emulator:
            return "owner"
        case .staticToken(let token):
            return token
        }
    }
}
