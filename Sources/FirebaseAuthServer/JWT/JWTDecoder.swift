import Foundation

/// Splits a Firebase ID token into its header, payload, and signature.
///
/// This is decoding only: Base64URL and JSON, with no signature or claim check of any kind. Treat
/// everything it returns as attacker-supplied until ``IDTokenVerifier`` has passed it.
struct JWTDecoder: Sendable {
    init() {}

    /// Decodes a JWT into its three parts plus the exact bytes the signature covers.
    /// - Parameter token: A JWT in `xxxxx.yyyyy.zzzzz` form.
    /// - Throws: ``AuthError/tokenInvalid(reason:)`` if the token does not have three parts, if a part
    ///   is not valid Base64URL, or if the header or payload JSON is missing a required claim.
    func decode(_ token: String) throws -> DecodedJWT {
        // omittingEmptySubsequences: false keeps an empty signature part,
        // because the Firebase emulator returns unsigned tokens shaped as `header.payload.`
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)

        guard parts.count == 3 else {
            throw AuthError.tokenInvalid(
                reason: "JWT must have 3 parts separated by '.', got \(parts.count)"
            )
        }

        let headerPart = String(parts[0])
        let payloadPart = String(parts[1])
        let signaturePart = String(parts[2])

        // Decode the header
        let headerData = try decodeBase64URL(headerPart, component: "header")
        let header: JWTHeader
        do {
            header = try JSONDecoder().decode(JWTHeader.self, from: headerData)
        } catch {
            throw AuthError.tokenInvalid(reason: "Failed to parse JWT header: \(error)")
        }

        // Decode the payload
        let payloadData = try decodeBase64URL(payloadPart, component: "payload")
        let payload: JWTPayload
        do {
            payload = try JSONDecoder().decode(JWTPayload.self, from: payloadData)
        } catch {
            throw AuthError.tokenInvalid(reason: "Failed to parse JWT payload: \(error)")
        }

        // Decode the signature, which can be empty in emulator mode
        let signature: Data
        if signaturePart.isEmpty {
            signature = Data()
        } else {
            signature = try decodeBase64URL(signaturePart, component: "signature")
        }

        // The bytes the signature covers: header.payload, still Base64URL-encoded
        let signedData = Data("\(headerPart).\(payloadPart)".utf8)

        return DecodedJWT(
            header: header,
            payload: payload,
            signature: signature,
            signedData: signedData
        )
    }

    /// Decodes Base64URL by translating it to standard Base64 and restoring the padding JWT strips.
    /// - Parameters:
    ///   - string: The Base64URL-encoded text.
    ///   - component: The part name to quote in the error message.
    private func decodeBase64URL(_ string: String, component: String) throws -> Data {
        // Base64URL to standard Base64
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Restore padding
        let paddingLength = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: paddingLength)

        guard let data = Data(base64Encoded: base64) else {
            throw AuthError.tokenInvalid(
                reason: "Failed to decode Base64URL \(component)"
            )
        }

        return data
    }
}

// MARK: - DecodedJWT

/// The parts of a JWT after decoding, before any verification.
struct DecodedJWT: Sendable {
    let header: JWTHeader

    let payload: JWTPayload

    /// The raw signature bytes, empty for an unsigned emulator token.
    let signature: Data

    /// The bytes the signature covers: the Base64URL header and payload joined by a dot.
    let signedData: Data
}
