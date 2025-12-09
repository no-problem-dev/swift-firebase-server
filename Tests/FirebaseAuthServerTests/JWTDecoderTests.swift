import Testing
import Foundation
@testable import FirebaseAuthServer

@Suite("JWT Decoder Tests")
struct JWTDecoderTests {

    let decoder = JWTDecoder()

    // MARK: - Valid Token Decoding

    @Test("Decode valid JWT with all required fields")
    func testDecodeValidJWT() throws {
        // 有効な JWT を作成（署名は無効だがデコードは可能）
        let header = #"{"alg":"RS256","kid":"test-key-id","typ":"JWT"}"#
        let payload = #"{"exp":9999999999,"iat":1609459200,"aud":"test-project","iss":"https://securetoken.google.com/test-project","sub":"user123","auth_time":1609459200}"#
        let signature = "test-signature"

        let headerB64 = base64URLEncode(header)
        let payloadB64 = base64URLEncode(payload)
        let signatureB64 = base64URLEncode(signature)

        let token = "\(headerB64).\(payloadB64).\(signatureB64)"

        let decoded = try decoder.decode(token)

        #expect(decoded.header.alg == "RS256")
        #expect(decoded.header.kid == "test-key-id")
        #expect(decoded.header.typ == "JWT")
        #expect(decoded.payload.sub == "user123")
        #expect(decoded.payload.aud == "test-project")
    }

    @Test("Decode JWT with optional email field")
    func testDecodeJWTWithEmail() throws {
        let header = #"{"alg":"RS256","kid":"test-key-id"}"#
        let payload = #"{"exp":9999999999,"iat":1609459200,"aud":"test-project","iss":"https://securetoken.google.com/test-project","sub":"user123","auth_time":1609459200,"email":"test@example.com","email_verified":true}"#
        let signature = "test-signature"

        let token = createToken(header: header, payload: payload, signature: signature)
        let decoded = try decoder.decode(token)

        #expect(decoded.payload.email == "test@example.com")
        #expect(decoded.payload.email_verified == true)
    }

    @Test("Decode JWT with Firebase claims")
    func testDecodeJWTWithFirebaseClaims() throws {
        let header = #"{"alg":"RS256","kid":"test-key-id"}"#
        let payload = #"{"exp":9999999999,"iat":1609459200,"aud":"test-project","iss":"https://securetoken.google.com/test-project","sub":"user123","auth_time":1609459200,"firebase":{"sign_in_provider":"google.com"}}"#
        let signature = "test-signature"

        let token = createToken(header: header, payload: payload, signature: signature)
        let decoded = try decoder.decode(token)

        #expect(decoded.payload.firebase?.sign_in_provider == "google.com")
    }

    // MARK: - Invalid Token Format

    @Test("Fail on token with less than 3 parts")
    func testFailOnInvalidPartCount() throws {
        let invalidTokens = [
            "only-one-part",
            "two.parts",
            "one.two.three.four",
        ]

        for invalidToken in invalidTokens {
            #expect(throws: AuthError.self) {
                _ = try decoder.decode(invalidToken)
            }
        }
    }

    @Test("Fail on invalid Base64 header")
    func testFailOnInvalidBase64Header() throws {
        let token = "!!!invalid!!!.payload.signature"

        #expect(throws: AuthError.self) {
            _ = try decoder.decode(token)
        }
    }

    @Test("Fail on invalid JSON header")
    func testFailOnInvalidJSONHeader() throws {
        let header = "not-json"
        let payload = #"{"exp":9999999999,"iat":1609459200,"aud":"test","iss":"test","sub":"user","auth_time":1609459200}"#
        let token = createToken(header: header, payload: payload, signature: "sig")

        #expect(throws: AuthError.self) {
            _ = try decoder.decode(token)
        }
    }

    @Test("Fail on invalid JSON payload")
    func testFailOnInvalidJSONPayload() throws {
        let header = #"{"alg":"RS256","kid":"key"}"#
        let payload = "not-json"
        let token = createToken(header: header, payload: payload, signature: "sig")

        #expect(throws: AuthError.self) {
            _ = try decoder.decode(token)
        }
    }

    // MARK: - Computed Properties

    @Test("Payload dates are correctly converted")
    func testPayloadDateConversion() throws {
        let header = #"{"alg":"RS256","kid":"test-key-id"}"#
        // 2021-01-01 00:00:00 UTC = 1609459200
        let payload = #"{"exp":1609545600,"iat":1609459200,"aud":"test-project","iss":"https://securetoken.google.com/test-project","sub":"user123","auth_time":1609459200}"#
        let signature = "test-signature"

        let token = createToken(header: header, payload: payload, signature: signature)
        let decoded = try decoder.decode(token)

        #expect(decoded.payload.issuedAt == Date(timeIntervalSince1970: 1609459200))
        #expect(decoded.payload.authTime == Date(timeIntervalSince1970: 1609459200))
        #expect(decoded.payload.expiresAt == Date(timeIntervalSince1970: 1609545600))
    }

    @Test("UID is alias for sub claim")
    func testUIDAlias() throws {
        let header = #"{"alg":"RS256","kid":"test-key-id"}"#
        let payload = #"{"exp":9999999999,"iat":1609459200,"aud":"test-project","iss":"https://securetoken.google.com/test-project","sub":"firebase-user-id-123","auth_time":1609459200}"#
        let signature = "test-signature"

        let token = createToken(header: header, payload: payload, signature: signature)
        let decoded = try decoder.decode(token)

        #expect(decoded.payload.uid == "firebase-user-id-123")
        #expect(decoded.payload.uid == decoded.payload.sub)
    }

    // MARK: - Helpers

    private func createToken(header: String, payload: String, signature: String) -> String {
        "\(base64URLEncode(header)).\(base64URLEncode(payload)).\(base64URLEncode(signature))"
    }

    private func base64URLEncode(_ string: String) -> String {
        Data(string.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
