import Foundation
import Testing
@testable import FirebaseAuthServer
@testable import Internal

/// Verification of the checks that do not need Google's signing keys.
///
/// Emulator tokens are unsigned, so the emulator path is the whole verifier minus the signature
/// step: everything asserted here is a check the verifier can make on its own. The production
/// tests use tokens whose header carries no `kid`, which the signature step rejects before any
/// network round trip, so they never reach Google either.
@Suite("ID Token Verifier Tests")
struct IDTokenVerifierTests {

    // MARK: - Token Construction

    private static func base64URL(_ string: String) -> String {
        Data(string.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Builds an unsigned token of the shape the Firebase Auth emulator mints.
    private static func token(
        alg: String = "none",
        kid: String? = nil,
        projectId: String = "demo-project",
        sub: String = "user-123",
        exp: Date = Date().addingTimeInterval(3600),
        iat: Date = Date().addingTimeInterval(-60),
        authTime: Date = Date().addingTimeInterval(-60),
        aud: String? = nil,
        iss: String? = nil,
        signature: String = ""
    ) -> String {
        var header: [String: Any] = ["alg": alg, "typ": "JWT"]
        if let kid {
            header["kid"] = kid
        }
        let payload: [String: Any] = [
            "exp": Int(exp.timeIntervalSince1970),
            "iat": Int(iat.timeIntervalSince1970),
            "auth_time": Int(authTime.timeIntervalSince1970),
            "aud": aud ?? projectId,
            "iss": iss ?? "https://securetoken.google.com/\(projectId)",
            "sub": sub,
        ]

        let headerJSON = String(
            data: try! JSONSerialization.data(withJSONObject: header),
            encoding: .utf8
        )!
        let payloadJSON = String(
            data: try! JSONSerialization.data(withJSONObject: payload),
            encoding: .utf8
        )!

        return "\(base64URL(headerJSON)).\(base64URL(payloadJSON)).\(signature)"
    }

    private func verifier(emulator: Bool, projectId: String = "demo-project") -> IDTokenVerifier {
        let configuration = emulator
            ? AuthConfiguration.emulator(projectId: projectId)
            : AuthConfiguration(projectId: projectId)
        return IDTokenVerifier(
            configuration: configuration,
            publicKeyCache: PublicKeyCache(httpClientProvider: HTTPClientProvider())
        )
    }

    // MARK: - Emulator Mode

    @Test("Emulator - a well-formed current token is accepted")
    func emulatorAcceptsValidToken() async throws {
        let verified = try await verifier(emulator: true).verify(Self.token())

        #expect(verified.uid == "user-123")
    }

    @Test("Emulator - an expired token is rejected")
    func emulatorRejectsExpiredToken() async throws {
        let expired = Self.token(
            exp: Date().addingTimeInterval(-3600),
            iat: Date().addingTimeInterval(-7200),
            authTime: Date().addingTimeInterval(-7200)
        )

        await #expect(throws: AuthError.self) {
            _ = try await verifier(emulator: true).verify(expired)
        }

        do {
            _ = try await verifier(emulator: true).verify(expired)
            Issue.record("Expected AuthError.tokenExpired")
        } catch let error as AuthError {
            guard case .tokenExpired = error else {
                Issue.record("Expected AuthError.tokenExpired, got \(error)")
                return
            }
        }
    }

    @Test("Emulator - a token minted for another project is rejected")
    func emulatorRejectsWrongAudience() async throws {
        let foreign = Self.token(aud: "other-project")

        do {
            _ = try await verifier(emulator: true).verify(foreign)
            Issue.record("Expected AuthError.invalidAudience")
        } catch let error as AuthError {
            guard case .invalidAudience(let expected, let actual) = error else {
                Issue.record("Expected AuthError.invalidAudience, got \(error)")
                return
            }
            #expect(expected == "demo-project")
            #expect(actual == "other-project")
        }
    }

    @Test("Emulator - a token from another issuer is rejected")
    func emulatorRejectsWrongIssuer() async throws {
        let foreign = Self.token(iss: "https://securetoken.google.com/other-project")

        do {
            _ = try await verifier(emulator: true).verify(foreign)
            Issue.record("Expected AuthError.invalidIssuer")
        } catch let error as AuthError {
            guard case .invalidIssuer = error else {
                Issue.record("Expected AuthError.invalidIssuer, got \(error)")
                return
            }
        }
    }

    @Test("Emulator - a token issued in the future is rejected")
    func emulatorRejectsFutureIssuedAt() async throws {
        let future = Self.token(iat: Date().addingTimeInterval(3600))

        do {
            _ = try await verifier(emulator: true).verify(future)
            Issue.record("Expected AuthError.tokenInvalid")
        } catch let error as AuthError {
            guard case .tokenInvalid = error else {
                Issue.record("Expected AuthError.tokenInvalid, got \(error)")
                return
            }
        }
    }

    @Test("Emulator - a token with an empty subject is rejected")
    func emulatorRejectsEmptySubject() async throws {
        do {
            _ = try await verifier(emulator: true).verify(Self.token(sub: ""))
            Issue.record("Expected AuthError.userNotFound")
        } catch let error as AuthError {
            guard case .userNotFound = error else {
                Issue.record("Expected AuthError.userNotFound, got \(error)")
                return
            }
        }
    }

    @Test("Emulator - a token that is not three parts is rejected")
    func emulatorRejectsMalformedToken() async throws {
        await #expect(throws: AuthError.self) {
            _ = try await verifier(emulator: true).verify("not-a-jwt")
        }
    }

    // MARK: - Production Mode

    @Test("Production - the signature is checked before any claim")
    func productionChecksSignatureBeforeClaims() async throws {
        // Expired *and* unsignable: the header carries no `kid`, so the signature step fails
        // without contacting Google. Whichever error comes back names the step that ran first.
        let expiredAndUnsignable = Self.token(
            alg: "RS256",
            kid: nil,
            exp: Date().addingTimeInterval(-3600),
            iat: Date().addingTimeInterval(-7200),
            authTime: Date().addingTimeInterval(-7200),
            signature: "c2lnbmF0dXJl"
        )

        do {
            _ = try await verifier(emulator: false).verify(expiredAndUnsignable)
            Issue.record("Expected the signature step to reject the token")
        } catch let error as AuthError {
            guard case .tokenInvalid(let reason) = error else {
                Issue.record("Expected AuthError.tokenInvalid from the signature step, got \(error)")
                return
            }
            #expect(reason.contains("kid"))
        }
    }

    @Test("Production - an unsigned emulator token is rejected")
    func productionRejectsUnsignedToken() async throws {
        do {
            _ = try await verifier(emulator: false).verify(Self.token())
            Issue.record("Expected AuthError.unsupportedAlgorithm")
        } catch let error as AuthError {
            guard case .unsupportedAlgorithm(let alg) = error else {
                Issue.record("Expected AuthError.unsupportedAlgorithm, got \(error)")
                return
            }
            #expect(alg == "none")
        }
    }
}
