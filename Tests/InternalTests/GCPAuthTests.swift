import Foundation
import Testing

@testable import Internal

@Suite("GCPAuth Tests")
struct GCPAuthTests {
    // MARK: - TokenCache Tests

    @Test("TokenCache - isValid returns true for fresh token")
    func tokenCacheFreshToken() {
        let cache = TokenCache(token: "test-token", expiresIn: 3600)
        #expect(cache.isValid)
    }

    @Test("TokenCache - isValid returns false for expired token")
    func tokenCacheExpiredToken() {
        // expiresIn が負の値だと即座に期限切れ
        let cache = TokenCache(token: "test-token", expiresIn: -1)
        #expect(!cache.isValid)
    }

    @Test("TokenCache - isValid returns false for token expiring soon")
    func tokenCacheExpiringSoon() {
        // 5分以内に期限切れの場合は無効とみなす
        let cache = TokenCache(token: "test-token", expiresIn: 200)  // 200秒 < 300秒
        #expect(!cache.isValid)
    }

    @Test("TokenCache - stores token correctly")
    func tokenCacheStoresToken() {
        let cache = TokenCache(token: "my-access-token", expiresIn: 3600)
        #expect(cache.token == "my-access-token")
    }

    // MARK: - GCPAuthError Tests

    @Test("GCPAuthError - metadataServerUnavailable has description")
    func errorMetadataUnavailable() {
        let error = GCPAuthError.metadataServerUnavailable
        #expect(error.errorDescription?.contains("metadata server") == true)
    }

    @Test("GCPAuthError - tokenFetchFailed includes message")
    func errorTokenFetchFailed() {
        let error = GCPAuthError.tokenFetchFailed("HTTP 500")
        #expect(error.errorDescription?.contains("HTTP 500") == true)
    }

    @Test("GCPAuthError - gcloudNotAvailable has description")
    func errorGcloudNotAvailable() {
        let error = GCPAuthError.gcloudNotAvailable
        #expect(error.errorDescription?.contains("gcloud") == true)
    }

    @Test("GCPAuthError - gcloudExecutionFailed includes message")
    func errorGcloudExecutionFailed() {
        let error = GCPAuthError.gcloudExecutionFailed("Permission denied")
        #expect(error.errorDescription?.contains("Permission denied") == true)
    }
}
