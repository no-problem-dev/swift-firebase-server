import Foundation

/// JWT ヘッダー
///
/// Firebase ID トークンの検証に必要なヘッダー情報を保持。
/// - `alg`: 署名アルゴリズム（Firebase は RS256 を使用、エミュレーターは none）
/// - `kid`: 公開鍵の識別子（オプション、エミュレーターでは省略される）
struct JWTHeader: Codable, Sendable {
    /// 署名アルゴリズム
    ///
    /// Firebase ID トークンでは `RS256` 固定
    /// エミュレーターでは `none`
    let alg: String

    /// 鍵ID（オプション）
    ///
    /// Google の公開鍵エンドポイントから対応する公開鍵を取得するために使用
    /// エミュレーターモードでは省略される
    let kid: String?

    /// トークンタイプ（オプション）
    let typ: String?

    init(alg: String, kid: String? = nil, typ: String? = nil) {
        self.alg = alg
        self.kid = kid
        self.typ = typ
    }
}
