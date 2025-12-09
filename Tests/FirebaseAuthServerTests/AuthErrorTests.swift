import Testing
import Foundation
@testable import FirebaseAuthServer

@Suite("Auth Error Tests")
struct AuthErrorTests {

    // MARK: - Error Code Mapping

    @Test("Token missing error code")
    func testTokenMissingErrorCode() {
        let error = AuthError.tokenMissing
        #expect(error.errorCode == "AUTH_TOKEN_MISSING")
    }

    @Test("Token invalid error code")
    func testTokenInvalidErrorCode() {
        let error = AuthError.tokenInvalid(reason: "Bad format")
        #expect(error.errorCode == "AUTH_TOKEN_INVALID")
    }

    @Test("Token expired error code")
    func testTokenExpiredErrorCode() {
        let error = AuthError.tokenExpired(expiredAt: Date())
        #expect(error.errorCode == "AUTH_TOKEN_EXPIRED")
    }

    @Test("Verification failed errors have same code")
    func testVerificationFailedErrorCodes() {
        let errors: [AuthError] = [
            .verificationFailed(reason: "test"),
            .unsupportedAlgorithm("HS256"),
            .signatureInvalid,
            .invalidIssuer(expected: "a", actual: "b"),
            .invalidAudience(expected: "a", actual: "b"),
            .publicKeyFetchFailed(underlying: NSError(domain: "", code: 0)),
            .publicKeyNotFound(kid: "test"),
            .invalidPublicKey(reason: "test"),
        ]

        for error in errors {
            #expect(error.errorCode == "AUTH_VERIFICATION_FAILED")
        }
    }

    @Test("User not found error code")
    func testUserNotFoundErrorCode() {
        let error = AuthError.userNotFound
        #expect(error.errorCode == "AUTH_USER_NOT_FOUND")
    }

    // MARK: - Error Descriptions

    @Test("Token missing description")
    func testTokenMissingDescription() {
        let error = AuthError.tokenMissing
        #expect(error.description.contains("Authorization header"))
    }

    @Test("Token invalid description includes reason")
    func testTokenInvalidDescription() {
        let error = AuthError.tokenInvalid(reason: "missing dot separator")
        #expect(error.description.contains("missing dot separator"))
    }

    @Test("Token expired description includes date")
    func testTokenExpiredDescription() {
        let expiry = Date(timeIntervalSince1970: 1609459200) // 2021-01-01
        let error = AuthError.tokenExpired(expiredAt: expiry)
        #expect(error.description.contains("2021-01-01"))
    }

    @Test("Invalid issuer description includes both values")
    func testInvalidIssuerDescription() {
        let error = AuthError.invalidIssuer(
            expected: "https://expected.com",
            actual: "https://actual.com"
        )
        #expect(error.description.contains("https://expected.com"))
        #expect(error.description.contains("https://actual.com"))
    }

    @Test("Invalid audience description includes both values")
    func testInvalidAudienceDescription() {
        let error = AuthError.invalidAudience(
            expected: "expected-project",
            actual: "actual-project"
        )
        #expect(error.description.contains("expected-project"))
        #expect(error.description.contains("actual-project"))
    }

    @Test("Public key not found description includes kid")
    func testPublicKeyNotFoundDescription() {
        let error = AuthError.publicKeyNotFound(kid: "key-123")
        #expect(error.description.contains("key-123"))
    }

    @Test("Unsupported algorithm description")
    func testUnsupportedAlgorithmDescription() {
        let error = AuthError.unsupportedAlgorithm("HS256")
        #expect(error.description.contains("HS256"))
        #expect(error.description.contains("RS256"))
    }
}
