import Testing
import Foundation
@testable import AuthServer

@Suite("Verified Token Tests")
struct VerifiedTokenTests {

    // MARK: - Token Creation

    @Test("Create verified token with all fields")
    func testCreateFullToken() {
        let now = Date()
        let expiry = now.addingTimeInterval(3600)

        let token = VerifiedToken(
            uid: "user-123",
            email: "test@example.com",
            emailVerified: true,
            name: "Test User",
            picture: "https://example.com/photo.jpg",
            phoneNumber: "+1234567890",
            authTime: now,
            issuedAt: now,
            expiresAt: expiry,
            signInProvider: "google.com"
        )

        #expect(token.uid == "user-123")
        #expect(token.email == "test@example.com")
        #expect(token.emailVerified == true)
        #expect(token.name == "Test User")
        #expect(token.picture == "https://example.com/photo.jpg")
        #expect(token.phoneNumber == "+1234567890")
        #expect(token.signInProvider == "google.com")
    }

    @Test("Create verified token with minimal fields")
    func testCreateMinimalToken() {
        let now = Date()
        let expiry = now.addingTimeInterval(3600)

        let token = VerifiedToken(
            uid: "user-456",
            authTime: now,
            issuedAt: now,
            expiresAt: expiry
        )

        #expect(token.uid == "user-456")
        #expect(token.email == nil)
        #expect(token.emailVerified == false)
        #expect(token.name == nil)
        #expect(token.picture == nil)
        #expect(token.phoneNumber == nil)
        #expect(token.signInProvider == nil)
    }

    // MARK: - Equatable

    @Test("Identical tokens are equal")
    func testIdenticalTokensEqual() {
        let now = Date()
        let expiry = now.addingTimeInterval(3600)

        let token1 = VerifiedToken(
            uid: "user-123",
            email: "test@example.com",
            emailVerified: true,
            authTime: now,
            issuedAt: now,
            expiresAt: expiry
        )

        let token2 = VerifiedToken(
            uid: "user-123",
            email: "test@example.com",
            emailVerified: true,
            authTime: now,
            issuedAt: now,
            expiresAt: expiry
        )

        #expect(token1 == token2)
    }

    @Test("Different UIDs are not equal")
    func testDifferentUIDsNotEqual() {
        let now = Date()
        let expiry = now.addingTimeInterval(3600)

        let token1 = VerifiedToken(uid: "user-123", authTime: now, issuedAt: now, expiresAt: expiry)
        let token2 = VerifiedToken(uid: "user-456", authTime: now, issuedAt: now, expiresAt: expiry)

        #expect(token1 != token2)
    }

    // MARK: - Description

    @Test("Description includes uid")
    func testDescriptionIncludesUID() {
        let now = Date()
        let token = VerifiedToken(
            uid: "my-user-id",
            authTime: now,
            issuedAt: now,
            expiresAt: now.addingTimeInterval(3600)
        )

        #expect(token.description.contains("my-user-id"))
    }

    @Test("Description includes email when present")
    func testDescriptionIncludesEmail() {
        let now = Date()
        let token = VerifiedToken(
            uid: "user-123",
            email: "test@example.com",
            authTime: now,
            issuedAt: now,
            expiresAt: now.addingTimeInterval(3600)
        )

        #expect(token.description.contains("test@example.com"))
    }

    @Test("Description shows nil for missing email")
    func testDescriptionShowsNilForMissingEmail() {
        let now = Date()
        let token = VerifiedToken(
            uid: "user-123",
            authTime: now,
            issuedAt: now,
            expiresAt: now.addingTimeInterval(3600)
        )

        #expect(token.description.contains("nil"))
    }

    // MARK: - JWTPayload Initialization

    @Test("Initialize from JWT payload with full data")
    func testInitFromJWTPayloadFull() throws {
        let header = #"{"alg":"RS256","kid":"test-key-id"}"#
        let payload = """
        {"exp":9999999999,"iat":1609459200,"aud":"test-project","iss":"https://securetoken.google.com/test-project","sub":"user123","auth_time":1609459200,"email":"user@test.com","email_verified":true,"name":"Test User","picture":"https://example.com/photo.jpg","phone_number":"+1234567890","firebase":{"sign_in_provider":"google.com"}}
        """

        let decoder = JWTDecoder()
        let token = createToken(header: header, payload: payload)
        let decoded = try decoder.decode(token)
        let verified = VerifiedToken(payload: decoded.payload)

        #expect(verified.uid == "user123")
        #expect(verified.email == "user@test.com")
        #expect(verified.emailVerified == true)
        #expect(verified.name == "Test User")
        #expect(verified.picture == "https://example.com/photo.jpg")
        #expect(verified.phoneNumber == "+1234567890")
        #expect(verified.signInProvider == "google.com")
    }

    @Test("Initialize from JWT payload with minimal data")
    func testInitFromJWTPayloadMinimal() throws {
        let header = #"{"alg":"RS256","kid":"test-key-id"}"#
        let payload = #"{"exp":9999999999,"iat":1609459200,"aud":"test-project","iss":"https://securetoken.google.com/test-project","sub":"user456","auth_time":1609459200}"#

        let decoder = JWTDecoder()
        let token = createToken(header: header, payload: payload)
        let decoded = try decoder.decode(token)
        let verified = VerifiedToken(payload: decoded.payload)

        #expect(verified.uid == "user456")
        #expect(verified.email == nil)
        #expect(verified.emailVerified == false)
        #expect(verified.name == nil)
        #expect(verified.signInProvider == nil)
    }

    // MARK: - Helpers

    private func createToken(header: String, payload: String) -> String {
        "\(base64URLEncode(header)).\(base64URLEncode(payload)).\(base64URLEncode("signature"))"
    }

    private func base64URLEncode(_ string: String) -> String {
        Data(string.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
