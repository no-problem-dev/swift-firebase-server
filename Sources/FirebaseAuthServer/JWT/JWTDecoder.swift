import Foundation

/// JWT デコーダー
///
/// Firebase ID トークン（JWT）を解析し、ヘッダー・ペイロード・署名に分解する。
/// Base64URL デコードと JSON パースを担当。
struct JWTDecoder: Sendable {
    init() {}

    /// JWT トークンを分解してデコード
    /// - Parameter token: JWT 文字列（"xxxxx.yyyyy.zzzzz" 形式）
    /// - Returns: デコード結果（ヘッダー、ペイロード、署名、署名対象データ）
    /// - Throws: `AuthError.tokenInvalid` デコードに失敗した場合
    func decode(_ token: String) throws -> DecodedJWT {
        // omittingEmptySubsequences: false で空のシグネチャ部分も保持
        // Firebase エミュレーターは署名なしのトークン（header.payload.）を返すため
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)

        guard parts.count == 3 else {
            throw AuthError.tokenInvalid(
                reason: "JWT must have 3 parts separated by '.', got \(parts.count)"
            )
        }

        let headerPart = String(parts[0])
        let payloadPart = String(parts[1])
        let signaturePart = String(parts[2])

        // ヘッダーのデコード
        let headerData = try decodeBase64URL(headerPart, component: "header")
        let header: JWTHeader
        do {
            header = try JSONDecoder().decode(JWTHeader.self, from: headerData)
        } catch {
            throw AuthError.tokenInvalid(reason: "Failed to parse JWT header: \(error)")
        }

        // ペイロードのデコード
        let payloadData = try decodeBase64URL(payloadPart, component: "payload")
        let payload: JWTPayload
        do {
            payload = try JSONDecoder().decode(JWTPayload.self, from: payloadData)
        } catch {
            throw AuthError.tokenInvalid(reason: "Failed to parse JWT payload: \(error)")
        }

        // 署名のデコード（エミュレーターモードでは空の場合がある）
        let signature: Data
        if signaturePart.isEmpty {
            signature = Data()
        } else {
            signature = try decodeBase64URL(signaturePart, component: "signature")
        }

        // 署名対象データ（header.payload）
        let signedData = Data("\(headerPart).\(payloadPart)".utf8)

        return DecodedJWT(
            header: header,
            payload: payload,
            signature: signature,
            signedData: signedData
        )
    }

    /// Base64URL デコード
    /// - Parameters:
    ///   - string: Base64URL エンコードされた文字列
    ///   - component: エラーメッセージ用のコンポーネント名
    /// - Returns: デコードされたデータ
    private func decodeBase64URL(_ string: String, component: String) throws -> Data {
        // Base64URL → 標準 Base64 変換
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // パディング追加
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

/// デコードされた JWT
struct DecodedJWT: Sendable {
    /// JWT ヘッダー
    let header: JWTHeader

    /// JWT ペイロード（クレーム）
    let payload: JWTPayload

    /// 署名バイナリ
    let signature: Data

    /// 署名対象データ（header.payload）
    let signedData: Data
}
