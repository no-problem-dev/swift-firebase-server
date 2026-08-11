import Foundation
import Crypto
import _CryptoExtras

/// Verifies Firebase ID tokens issued by Firebase Authentication.
///
/// The production implementation is ``IDTokenVerifier``. Conform a test double to this protocol to
/// inject verification results without reaching Google's public key endpoint.
public protocol IDTokenVerifying: Sendable {
    /// Checks a token's signature and claims and returns the identity it carries.
    /// - Parameter idToken: The raw JWT sent by a Firebase client, without any `Bearer ` prefix.
    /// - Throws: ``AuthError`` if the token is malformed, expired, issued for another project, or
    ///   signed by a key Google does not publish.
    func verify(_ idToken: String) async throws -> VerifiedToken
}

/// Verifies Firebase ID tokens against Google's published signing keys.
///
/// A production verification runs these steps in order and throws ``AuthError`` on the first failure:
///
/// 1. The token splits into exactly three dot-separated Base64URL parts.
/// 2. The header's `alg` is exactly `RS256`.
/// 3. The RS256 signature, against the Google certificate named by the header's `kid`.
/// 4. The claims: `exp` is not past, `iat` and `auth_time` are not in the future, `aud` equals the
///    project ID, `iss` equals `https://securetoken.google.com/{projectId}`, and `sub` is non-empty.
///    Every time comparison allows `clockSkewTolerance` of slack in the relevant direction.
///
/// The signature is checked before the claims, so no claim is read from a token that has not been
/// shown to be genuine first.
///
/// Nothing beyond that list is checked. Revocation and account-disabled state are not checked (that
/// needs an Admin API lookup), the `typ` header and any custom claims are ignored, `nbf` is ignored,
/// and the certificate that carries the public key is used only as a container for that key — its
/// validity dates, extensions, and issuer signature are never verified.
///
/// - Warning: When ``AuthConfiguration/useEmulator`` is set, step 3 is skipped — emulator tokens are
///   unsigned, so nothing there proves the token came from anywhere. The structure and every claim in
///   step 4 are still checked. Never give a production deployment an emulator configuration.
public final class IDTokenVerifier: IDTokenVerifying, Sendable {
    private let configuration: AuthConfiguration

    private let publicKeyCache: PublicKeyCache

    private let jwtDecoder: JWTDecoder

    /// How far the `exp`, `iat`, and `auth_time` claims may disagree with this machine's clock, in seconds.
    ///
    /// A token stays acceptable for this long after `exp`, and `iat` or `auth_time` may sit this far
    /// in the future without being rejected.
    private let clockSkewTolerance: TimeInterval

    // MARK: - Initializers

    /// Creates a verifier bound to a single Firebase project.
    /// - Parameters:
    ///   - configuration: Supplies the expected issuer and audience, and whether to bypass verification for the emulator.
    ///   - publicKeyCache: Supplies Google's signing certificates, looked up by key ID.
    ///   - clockSkewTolerance: How far clocks may disagree, in seconds. Defaults to five minutes.
    public init(
        configuration: AuthConfiguration,
        publicKeyCache: PublicKeyCache,
        clockSkewTolerance: TimeInterval = 300
    ) {
        self.configuration = configuration
        self.publicKeyCache = publicKeyCache
        self.jwtDecoder = JWTDecoder()
        self.clockSkewTolerance = clockSkewTolerance
    }

    // MARK: - IDTokenVerifying

    public func verify(_ idToken: String) async throws -> VerifiedToken {
        // In emulator mode, only the signature check is out of reach
        if configuration.useEmulator {
            return try verifyEmulatorToken(idToken)
        }

        // 1. Decode the JWT
        let decoded = try jwtDecoder.decode(idToken)

        // 2. Check the algorithm
        guard decoded.header.alg == "RS256" else {
            throw AuthError.unsupportedAlgorithm(decoded.header.alg)
        }

        // 3. Check the signature, before anything reads a claim out of the token
        try await verifySignature(decoded)

        // 4. Check the claims
        try validateClaims(decoded.payload)

        // 5. Hand back the verified token
        return VerifiedToken(payload: decoded.payload)
    }

    // MARK: - Private Methods

    /// Checks the time, audience, issuer, and subject claims of a decoded token.
    private func validateClaims(_ payload: JWTPayload) throws {
        let now = Date()

        // exp: must not be more than `clockSkewTolerance` in the past
        if payload.expiresAt.addingTimeInterval(clockSkewTolerance) < now {
            throw AuthError.tokenExpired(expiredAt: payload.expiresAt)
        }

        // iat: must not be more than `clockSkewTolerance` in the future
        if payload.issuedAt.addingTimeInterval(-clockSkewTolerance) > now {
            throw AuthError.tokenInvalid(reason: "Token issued in the future")
        }

        // auth_time: must not be more than `clockSkewTolerance` in the future
        if payload.authTime.addingTimeInterval(-clockSkewTolerance) > now {
            throw AuthError.tokenInvalid(reason: "Auth time is in the future")
        }

        // aud: must equal the project ID
        guard payload.aud == configuration.expectedAudience else {
            throw AuthError.invalidAudience(
                expected: configuration.expectedAudience,
                actual: payload.aud
            )
        }

        // iss: must equal https://securetoken.google.com/{projectId}
        guard payload.iss == configuration.expectedIssuer else {
            throw AuthError.invalidIssuer(
                expected: configuration.expectedIssuer,
                actual: payload.iss
            )
        }

        // sub: must be a non-empty string
        guard !payload.sub.isEmpty else {
            throw AuthError.userNotFound
        }
    }

    /// Checks the RS256 signature against the Google certificate named by the header's `kid`.
    ///
    /// A cache miss on the key ID costs a network round trip to Google.
    private func verifySignature(_ decoded: DecodedJWT) async throws {
        // `kid` is required here; this path only runs outside emulator mode
        guard let kid = decoded.header.kid else {
            throw AuthError.tokenInvalid(reason: "Missing 'kid' in JWT header")
        }

        // Fetch the public key
        let pemCertificate = try await publicKeyCache.getPublicKey(for: kid)

        // Pull the public key out of the PEM
        let publicKey = try extractPublicKey(from: pemCertificate)

        // Check the signature
        let isValid = try verifyRS256Signature(
            signedData: decoded.signedData,
            signature: decoded.signature,
            publicKey: publicKey
        )

        guard isValid else {
            throw AuthError.signatureInvalid
        }
    }

    /// Pulls the RSA public key out of a PEM-encoded X.509 certificate.
    ///
    /// Only the key is taken. The certificate's validity dates, extensions, and issuer signature are
    /// never looked at, so this is not a certificate validation.
    private func extractPublicKey(from pemCertificate: String) throws -> _RSA.Signing.PublicKey {
        // Strip the PEM header and footer, then Base64-decode the body
        let pemContent = pemCertificate
            .replacingOccurrences(of: "-----BEGIN CERTIFICATE-----", with: "")
            .replacingOccurrences(of: "-----END CERTIFICATE-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")

        guard let derData = Data(base64Encoded: pemContent) else {
            throw AuthError.invalidPublicKey(reason: "Failed to decode Base64 certificate")
        }

        // Take the public key out of the DER-encoded X.509 certificate:
        // walk the certificate structure down to its SubjectPublicKeyInfo
        let publicKeyData = try extractSubjectPublicKeyInfo(from: derData)

        do {
            return try _RSA.Signing.PublicKey(derRepresentation: publicKeyData)
        } catch {
            throw AuthError.invalidPublicKey(reason: "Failed to parse RSA public key: \(error)")
        }
    }

    /// Walks the ASN.1 DER of an X.509 certificate and returns its `SubjectPublicKeyInfo`.
    ///
    /// The returned bytes keep the outer `SEQUENCE` tag and length, which is the DER representation
    /// the RSA public key initializer expects.
    private func extractSubjectPublicKeyInfo(from derData: Data) throws -> Data {
        // ASN.1 structure of an X.509 certificate:
        // Certificate ::= SEQUENCE {
        //   tbsCertificate TBSCertificate,
        //   signatureAlgorithm AlgorithmIdentifier,
        //   signatureValue BIT STRING
        // }
        //
        // TBSCertificate ::= SEQUENCE {
        //   version [0] EXPLICIT Version DEFAULT v1,
        //   serialNumber CertificateSerialNumber,
        //   signature AlgorithmIdentifier,
        //   issuer Name,
        //   validity Validity,
        //   subject Name,
        //   subjectPublicKeyInfo SubjectPublicKeyInfo,  <- the part we want
        //   ...
        // }

        var index = 0
        let bytes = [UInt8](derData)

        // Certificate SEQUENCE
        guard bytes[index] == 0x30 else {
            throw AuthError.invalidPublicKey(reason: "Invalid certificate: expected SEQUENCE")
        }
        index += 1
        _ = try readLength(bytes: bytes, index: &index)

        // TBSCertificate SEQUENCE
        guard bytes[index] == 0x30 else {
            throw AuthError.invalidPublicKey(reason: "Invalid TBSCertificate: expected SEQUENCE")
        }
        index += 1
        _ = try readLength(bytes: bytes, index: &index)

        // version [0] (optional, skip if present)
        if bytes[index] == 0xA0 {
            index += 1
            let versionLength = try readLength(bytes: bytes, index: &index)
            index += versionLength
        }

        // serialNumber (skip)
        try skipElement(bytes: bytes, index: &index)

        // signature AlgorithmIdentifier (skip)
        try skipElement(bytes: bytes, index: &index)

        // issuer Name (skip)
        try skipElement(bytes: bytes, index: &index)

        // validity Validity (skip)
        try skipElement(bytes: bytes, index: &index)

        // subject Name (skip)
        try skipElement(bytes: bytes, index: &index)

        // subjectPublicKeyInfo SubjectPublicKeyInfo - the part we want
        let spkiStart = index
        guard bytes[index] == 0x30 else {
            throw AuthError.invalidPublicKey(reason: "Invalid SubjectPublicKeyInfo: expected SEQUENCE")
        }
        index += 1
        let spkiContentLength = try readLength(bytes: bytes, index: &index)
        let spkiEnd = index + spkiContentLength

        // Return the whole SubjectPublicKeyInfo, including its SEQUENCE tag and length
        return Data(bytes[spkiStart..<spkiEnd])
    }

    /// Reads the ASN.1 length at `index` and advances `index` past the length bytes.
    ///
    /// Handles both the short and the long definite form. The indefinite form is not supported, and
    /// neither is a length that runs past the end of the data.
    private func readLength(bytes: [UInt8], index: inout Int) throws -> Int {
        guard index < bytes.count else {
            throw AuthError.invalidPublicKey(reason: "Unexpected end of data")
        }

        let firstByte = bytes[index]
        index += 1

        if firstByte & 0x80 == 0 {
            // Short form: the single byte is the length
            return Int(firstByte)
        } else {
            // Long form: the first byte says how many bytes carry the length
            let lengthBytes = Int(firstByte & 0x7F)
            guard index + lengthBytes <= bytes.count else {
                throw AuthError.invalidPublicKey(reason: "Invalid length encoding")
            }

            var length = 0
            for _ in 0..<lengthBytes {
                length = (length << 8) | Int(bytes[index])
                index += 1
            }
            return length
        }
    }

    /// Advances `index` past one complete ASN.1 element: its tag, its length, and its contents.
    private func skipElement(bytes: [UInt8], index: inout Int) throws {
        guard index < bytes.count else {
            throw AuthError.invalidPublicKey(reason: "Unexpected end of data")
        }

        index += 1 // skip the tag
        let length = try readLength(bytes: bytes, index: &index)
        index += length
    }

    /// Checks an RSASSA-PKCS1-v1_5 signature over the SHA-256 digest of `signedData`.
    ///
    /// That pairing is what `RS256` names in a JWT header. The padding is spelled `insecurePKCS1v1_5`
    /// because PSS is preferred for new designs, but PKCS#1 v1.5 is the padding JWT `RS256` requires
    /// and the only one Firebase issues.
    private func verifyRS256Signature(
        signedData: Data,
        signature: Data,
        publicKey: _RSA.Signing.PublicKey
    ) throws -> Bool {
        let rsaSignature = _RSA.Signing.RSASignature(rawRepresentation: signature)

        return publicKey.isValidSignature(
            rsaSignature,
            for: signedData,
            padding: .insecurePKCS1v1_5
        )
    }

    /// Checks everything a signature-less environment can check, for use against the Firebase Auth
    /// emulator.
    ///
    /// Emulator tokens are unsigned, so the signature step has nothing to work with and the token's
    /// origin cannot be established. Everything else is checked exactly as in production: the token
    /// has to decode into three parts with the required claims, and `exp`, `iat`, `auth_time`, `aud`,
    /// `iss`, and `sub` all have to hold. An expired token, or one minted for another project, is
    /// rejected here too.
    private func verifyEmulatorToken(_ idToken: String) throws -> VerifiedToken {
        let decoded = try jwtDecoder.decode(idToken)

        try validateClaims(decoded.payload)

        return VerifiedToken(payload: decoded.payload)
    }
}
