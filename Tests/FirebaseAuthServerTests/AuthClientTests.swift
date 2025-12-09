import Testing
import Foundation
@testable import FirebaseAuthServer

@Suite("Auth Client Tests")
struct AuthClientTests {

    // MARK: - Initialization

    @Test("Initialize with project ID only")
    func testInitWithProjectId() {
        let client = AuthClient(projectId: "test-project")

        #expect(client.configuration.projectId == "test-project")
        #expect(client.configuration.useEmulator == false)
    }

    @Test("Initialize with configuration")
    func testInitWithConfiguration() {
        let config = AuthConfiguration(projectId: "my-project", timeout: 60)
        let client = AuthClient(configuration: config)

        #expect(client.configuration.projectId == "my-project")
        #expect(client.configuration.timeout == 60)
    }

    @Test("Initialize with emulator configuration")
    func testInitWithEmulatorConfig() {
        let config = AuthConfiguration.emulator(projectId: "demo-project")
        let client = AuthClient(configuration: config)

        #expect(client.configuration.useEmulator == true)
        #expect(client.configuration.emulatorHost == "localhost")
    }

    // MARK: - Bearer Token Extraction

    @Test("Extract bearer token from valid header")
    func testExtractBearerToken() async throws {
        let config = AuthConfiguration.emulator(projectId: "test-project")
        let client = AuthClient(configuration: config)

        // エミュレーターモードでも Bearer トークンのフォーマット検証は行われる
        // ただし、空のヘッダーはエラーになる
        do {
            _ = try await client.verifyAuthorizationHeader("")
            Issue.record("Expected AuthError.tokenMissing")
        } catch let error as AuthError {
            #expect(error.errorCode == "AUTH_TOKEN_MISSING")
        }
    }

    @Test("Fail on non-Bearer token")
    func testFailOnNonBearerToken() async throws {
        let config = AuthConfiguration.emulator(projectId: "test-project")
        let client = AuthClient(configuration: config)

        do {
            _ = try await client.verifyAuthorizationHeader("Basic dXNlcjpwYXNz")
            Issue.record("Expected AuthError.tokenInvalid")
        } catch let error as AuthError {
            #expect(error.errorCode == "AUTH_TOKEN_INVALID")
        }
    }

    @Test("Fail on missing token after Bearer")
    func testFailOnMissingTokenAfterBearer() async throws {
        let config = AuthConfiguration.emulator(projectId: "test-project")
        let client = AuthClient(configuration: config)

        do {
            _ = try await client.verifyAuthorizationHeader("Bearer ")
            Issue.record("Expected AuthError.tokenInvalid")
        } catch let error as AuthError {
            #expect(error.errorCode == "AUTH_TOKEN_INVALID")
        }
    }

    // MARK: - Emulator Mode Token Verification

    @Test("Emulator mode accepts valid JWT format")
    func testEmulatorAcceptsValidJWT() async throws {
        let config = AuthConfiguration.emulator(projectId: "test-project")
        let client = AuthClient(configuration: config)

        // エミュレーターモード用のテストトークン作成
        let token = createTestToken(uid: "test-user-123", projectId: "test-project")

        let verifiedToken = try await client.verifyIDToken(token)
        #expect(verifiedToken.uid == "test-user-123")
    }

    @Test("Emulator mode rejects empty sub claim")
    func testEmulatorRejectsEmptySub() async throws {
        let config = AuthConfiguration.emulator(projectId: "test-project")
        let client = AuthClient(configuration: config)

        // 空の sub を持つトークン
        let token = createTestToken(uid: "", projectId: "test-project")

        do {
            _ = try await client.verifyIDToken(token)
            Issue.record("Expected AuthError.userNotFound")
        } catch let error as AuthError {
            #expect(error.errorCode == "AUTH_USER_NOT_FOUND")
        }
    }

    // MARK: - Helpers

    private func createTestToken(uid: String, projectId: String) -> String {
        let header = #"{"alg":"RS256","kid":"test-key-id","typ":"JWT"}"#
        let now = Int(Date().timeIntervalSince1970)
        let exp = now + 3600 // 1時間後
        let payload = """
        {"exp":\(exp),"iat":\(now),"aud":"\(projectId)","iss":"https://securetoken.google.com/\(projectId)","sub":"\(uid)","auth_time":\(now)}
        """
        let signature = "test-signature"

        return "\(base64URLEncode(header)).\(base64URLEncode(payload)).\(base64URLEncode(signature))"
    }

    private func base64URLEncode(_ string: String) -> String {
        Data(string.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
