import Foundation

/// A failure while obtaining GCP credentials, from either the metadata server or gcloud.
public enum GCPAuthError: Error, LocalizedError, Sendable {
    /// The request to the metadata server never completed, which usually means the process is
    /// not running on Cloud Run.
    case metadataServerUnavailable
    /// The metadata server answered the token request with a status other than 200. The payload
    /// carries that status.
    case tokenFetchFailed(String)
    /// The token response was not JSON carrying both `access_token` and `expires_in`.
    case tokenParseFailed
    /// The project ID could not be read, from the metadata server or from gcloud. The payload
    /// says which and why.
    case projectIdFetchFailed(String)
    /// The gcloud executable could not be launched at all. Install the Google Cloud SDK.
    case gcloudNotAvailable
    /// gcloud ran but exited non-zero, or printed nothing. The payload carries its standard
    /// error output.
    case gcloudExecutionFailed(String)
    /// An access token was requested before its provider had been set up.
    ///
    /// Nothing in this package throws this case.
    case providerNotInitialized
    /// Neither Cloud Run nor a usable local setup could be identified.
    ///
    /// Nothing in this package throws this case: detection falls back to the local mode rather
    /// than failing, so a machine without gcloud surfaces `gcloudNotAvailable` instead.
    case environmentDetectionFailed

    public var errorDescription: String? {
        switch self {
        case .metadataServerUnavailable:
            return "GCP metadata server is not available. Are you running on Cloud Run?"
        case .tokenFetchFailed(let message):
            return "Failed to fetch access token: \(message)"
        case .tokenParseFailed:
            return "Failed to parse token response from metadata server"
        case .projectIdFetchFailed(let message):
            return "Failed to fetch project ID: \(message)"
        case .gcloudNotAvailable:
            return "gcloud CLI is not available. Please install Google Cloud SDK."
        case .gcloudExecutionFailed(let message):
            return "gcloud CLI execution failed: \(message)"
        case .providerNotInitialized:
            return "Access token provider is not initialized"
        case .environmentDetectionFailed:
            return "Failed to detect GCP environment. Use explicit configuration or run on Cloud Run/with gcloud CLI."
        }
    }
}
