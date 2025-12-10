import Foundation
import Crypto
import _CryptoExtras

/// Firebase ID トークン検証プロトコル
public protocol IDTokenVerifying: Sendable {
    /// ID トークンを検証し、検証済みトークンを返す
    /// - Parameter idToken: Firebase ID トークン文字列
    /// - Returns: 検証済みトークン
    /// - Throws: `AuthError` 検証に失敗した場合
    func verify(_ idToken: String) async throws -> VerifiedToken
}

/// Firebase ID トークン検証器
///
/// Firebase ID トークン（JWT）を検証し、ユーザー情報を抽出する。
/// 以下の検証を実行:
/// 1. JWT 形式の検証
/// 2. アルゴリズムの検証（RS256）
/// 3. 署名の検証（Google 公開鍵使用）
/// 4. クレームの検証（exp, iat, aud, iss, sub, auth_time）
public final class IDTokenVerifier: IDTokenVerifying, Sendable {
    /// 設定
    private let configuration: AuthConfiguration

    /// 公開鍵キャッシュ
    private let publicKeyCache: PublicKeyCache

    /// JWT デコーダー
    private let jwtDecoder: JWTDecoder

    /// 時刻許容範囲（秒）
    ///
    /// クロック同期のずれを考慮した許容範囲
    private let clockSkewTolerance: TimeInterval

    // MARK: - Initializers

    /// 初期化
    /// - Parameters:
    ///   - configuration: Auth 設定
    ///   - publicKeyCache: 公開鍵キャッシュ
    ///   - clockSkewTolerance: 時刻許容範囲（デフォルト: 5分）
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
        // エミュレーターモードの場合は署名検証をスキップ
        if configuration.useEmulator {
            return try verifyEmulatorToken(idToken)
        }

        // 1. JWT をデコード
        let decoded = try jwtDecoder.decode(idToken)

        // 2. アルゴリズムを検証
        guard decoded.header.alg == "RS256" else {
            throw AuthError.unsupportedAlgorithm(decoded.header.alg)
        }

        // 3. クレームを検証
        try validateClaims(decoded.payload)

        // 4. 署名を検証
        try await verifySignature(decoded)

        // 5. VerifiedToken を返す
        return VerifiedToken(payload: decoded.payload)
    }

    // MARK: - Private Methods

    /// クレームを検証
    private func validateClaims(_ payload: JWTPayload) throws {
        let now = Date()

        // exp: 有効期限が未来であること
        if payload.expiresAt.addingTimeInterval(clockSkewTolerance) < now {
            throw AuthError.tokenExpired(expiredAt: payload.expiresAt)
        }

        // iat: 発行時刻が過去であること
        if payload.issuedAt.addingTimeInterval(-clockSkewTolerance) > now {
            throw AuthError.tokenInvalid(reason: "Token issued in the future")
        }

        // auth_time: 認証時刻が過去であること
        if payload.authTime.addingTimeInterval(-clockSkewTolerance) > now {
            throw AuthError.tokenInvalid(reason: "Auth time is in the future")
        }

        // aud: プロジェクトID と一致
        guard payload.aud == configuration.expectedAudience else {
            throw AuthError.invalidAudience(
                expected: configuration.expectedAudience,
                actual: payload.aud
            )
        }

        // iss: 発行者が正しいこと
        guard payload.iss == configuration.expectedIssuer else {
            throw AuthError.invalidIssuer(
                expected: configuration.expectedIssuer,
                actual: payload.iss
            )
        }

        // sub: 非空文字列であること
        guard !payload.sub.isEmpty else {
            throw AuthError.userNotFound
        }
    }

    /// RS256 署名を検証
    private func verifySignature(_ decoded: DecodedJWT) async throws {
        // kid が必須（本番モードでのみ呼ばれる）
        guard let kid = decoded.header.kid else {
            throw AuthError.tokenInvalid(reason: "Missing 'kid' in JWT header")
        }

        // 公開鍵を取得
        let pemCertificate = try await publicKeyCache.getPublicKey(for: kid)

        // PEM から公開鍵を抽出
        let publicKey = try extractPublicKey(from: pemCertificate)

        // 署名を検証
        let isValid = try verifyRS256Signature(
            signedData: decoded.signedData,
            signature: decoded.signature,
            publicKey: publicKey
        )

        guard isValid else {
            throw AuthError.signatureInvalid
        }
    }

    /// PEM 形式の X.509 証明書から公開鍵を抽出
    private func extractPublicKey(from pemCertificate: String) throws -> _RSA.Signing.PublicKey {
        // PEM ヘッダー/フッターを除去して Base64 デコード
        let pemContent = pemCertificate
            .replacingOccurrences(of: "-----BEGIN CERTIFICATE-----", with: "")
            .replacingOccurrences(of: "-----END CERTIFICATE-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")

        guard let derData = Data(base64Encoded: pemContent) else {
            throw AuthError.invalidPublicKey(reason: "Failed to decode Base64 certificate")
        }

        // DER 形式の X.509 証明書から公開鍵を抽出
        // X.509 証明書の構造を解析して SubjectPublicKeyInfo を取得
        let publicKeyData = try extractSubjectPublicKeyInfo(from: derData)

        do {
            return try _RSA.Signing.PublicKey(derRepresentation: publicKeyData)
        } catch {
            throw AuthError.invalidPublicKey(reason: "Failed to parse RSA public key: \(error)")
        }
    }

    /// X.509 証明書から SubjectPublicKeyInfo を抽出
    ///
    /// ASN.1 DER 形式の X.509 証明書を解析し、公開鍵部分を取得
    private func extractSubjectPublicKeyInfo(from derData: Data) throws -> Data {
        // X.509 証明書の ASN.1 構造:
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
        //   subjectPublicKeyInfo SubjectPublicKeyInfo,  ← これを取得
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

        // subjectPublicKeyInfo SubjectPublicKeyInfo - これを取得
        let spkiStart = index
        guard bytes[index] == 0x30 else {
            throw AuthError.invalidPublicKey(reason: "Invalid SubjectPublicKeyInfo: expected SEQUENCE")
        }
        index += 1
        let spkiContentLength = try readLength(bytes: bytes, index: &index)
        let spkiEnd = index + spkiContentLength

        // SubjectPublicKeyInfo 全体を返す（SEQUENCE タグとレングスを含む）
        return Data(bytes[spkiStart..<spkiEnd])
    }

    /// ASN.1 長さを読み取る
    private func readLength(bytes: [UInt8], index: inout Int) throws -> Int {
        guard index < bytes.count else {
            throw AuthError.invalidPublicKey(reason: "Unexpected end of data")
        }

        let firstByte = bytes[index]
        index += 1

        if firstByte & 0x80 == 0 {
            // 短形式: 1バイトで長さを表現
            return Int(firstByte)
        } else {
            // 長形式: 最初のバイトが長さバイト数を示す
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

    /// ASN.1 要素をスキップ
    private func skipElement(bytes: [UInt8], index: inout Int) throws {
        guard index < bytes.count else {
            throw AuthError.invalidPublicKey(reason: "Unexpected end of data")
        }

        index += 1 // タグをスキップ
        let length = try readLength(bytes: bytes, index: &index)
        index += length
    }

    /// RS256 署名を検証
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

    /// エミュレーターモードでのトークン検証
    ///
    /// 署名検証をスキップし、クレームの基本検証のみ実行
    private func verifyEmulatorToken(_ idToken: String) throws -> VerifiedToken {
        let decoded = try jwtDecoder.decode(idToken)

        // sub が存在することのみ検証
        guard !decoded.payload.sub.isEmpty else {
            throw AuthError.userNotFound
        }

        return VerifiedToken(payload: decoded.payload)
    }
}
