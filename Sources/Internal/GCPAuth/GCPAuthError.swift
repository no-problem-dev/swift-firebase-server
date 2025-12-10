import Foundation

/// GCP認証関連のエラー
enum GCPAuthError: Error, LocalizedError, Sendable {
    /// メタデータサーバーへの接続失敗
    case metadataServerUnavailable
    /// トークンの取得に失敗
    case tokenFetchFailed(String)
    /// トークンのパースに失敗
    case tokenParseFailed
    /// gcloud CLIが利用できない
    case gcloudNotAvailable
    /// gcloud CLIの実行に失敗
    case gcloudExecutionFailed(String)
    /// 認証プロバイダーが初期化されていない
    case providerNotInitialized

    var errorDescription: String? {
        switch self {
        case .metadataServerUnavailable:
            return "GCP metadata server is not available. Are you running on Cloud Run?"
        case .tokenFetchFailed(let message):
            return "Failed to fetch access token: \(message)"
        case .tokenParseFailed:
            return "Failed to parse token response from metadata server"
        case .gcloudNotAvailable:
            return "gcloud CLI is not available. Please install Google Cloud SDK."
        case .gcloudExecutionFailed(let message):
            return "gcloud CLI execution failed: \(message)"
        case .providerNotInitialized:
            return "Access token provider is not initialized"
        }
    }
}
