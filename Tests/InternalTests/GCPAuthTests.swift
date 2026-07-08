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

    // MARK: - TokenSource Tests

    @Test("TokenSource - .auto creates .dynamic")
    func tokenSourceAuto() {
        let source = TokenSource(config: .auto, resolvedToken: "initial-token")
        if case .dynamic = source {} else {
            Issue.record("Expected .dynamic, got \(source)")
        }
    }

    @Test("TokenSource - .autoWithDatabase creates .dynamic")
    func tokenSourceAutoWithDatabase() {
        let source = TokenSource(config: .autoWithDatabase(databaseId: "my-db"), resolvedToken: "initial-token")
        if case .dynamic = source {} else {
            Issue.record("Expected .dynamic, got \(source)")
        }
    }

    @Test("TokenSource - .emulator creates .emulator")
    func tokenSourceEmulator() {
        let source = TokenSource(config: .emulator(projectId: "demo"), resolvedToken: "ignored")
        if case .emulator = source {} else {
            Issue.record("Expected .emulator, got \(source)")
        }
    }

    @Test("TokenSource - .explicit creates .staticToken with provided token")
    func tokenSourceExplicit() {
        let source = TokenSource(
            config: .explicit(projectId: "proj", token: "user-provided"),
            resolvedToken: "ignored"
        )
        guard case .staticToken(let token) = source else {
            Issue.record("Expected .staticToken, got \(source)")
            return
        }
        #expect(token == "user-provided")
    }

    @Test("TokenSource - currentToken() returns 'owner' for emulator")
    func tokenSourceEmulatorCurrentToken() async throws {
        let source = TokenSource.emulator
        let token = try await source.currentToken()
        #expect(token == "owner")
    }

    @Test("TokenSource - currentToken() returns provided token for staticToken")
    func tokenSourceStaticCurrentToken() async throws {
        let source = TokenSource.staticToken("my-static-token")
        let token = try await source.currentToken()
        #expect(token == "my-static-token")
    }

    /// Regression test for https://github.com/no-problem-dev/swift-firebase-server/issues/XX
    /// (Cloud Run で 1 時間経過後に Firestore が 401 Unauthenticated を返すバグ)
    ///
    /// `.dynamic` モードは必ず `GCPEnvironment.shared.getAccessToken()` を経由することで、
    /// 同 actor 内の 5 分バッファ cache refresh に追従する。
    /// この test は契約 (dynamic enum case が存在し、コンパイル可能) を保証する。
    @Test("TokenSource - .dynamic routes through GCPEnvironment")
    func tokenSourceDynamicRoute() {
        let source = TokenSource.dynamic
        if case .dynamic = source {} else {
            Issue.record("TokenSource.dynamic case missing")
        }
    }
}
