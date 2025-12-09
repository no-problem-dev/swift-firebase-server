import Foundation

/// JWT ヘッダー
///
/// Firebase ID トークンの検証に必要なヘッダー情報を保持。
/// - `alg`: 署名アルゴリズム（Firebase は RS256 を使用）
/// - `kid`: 公開鍵の識別子
public struct JWTHeader: Codable, Sendable {
    /// 署名アルゴリズム
    ///
    /// Firebase ID トークンでは `RS256` 固定
    public let alg: String

    /// 鍵ID
    ///
    /// Google の公開鍵エンドポイントから対応する公開鍵を取得するために使用
    public let kid: String

    /// トークンタイプ（オプション）
    public let typ: String?

    public init(alg: String, kid: String, typ: String? = nil) {
        self.alg = alg
        self.kid = kid
        self.typ = typ
    }
}
