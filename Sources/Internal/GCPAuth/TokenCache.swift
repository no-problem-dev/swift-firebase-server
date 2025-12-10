import Foundation

/// アクセストークンのキャッシュ
struct TokenCache: Sendable {
    /// アクセストークン
    let token: String
    /// 有効期限
    let expiresAt: Date

    /// キャッシュが有効かどうか（有効期限の5分前まで有効とみなす）
    var isValid: Bool {
        Date() < expiresAt.addingTimeInterval(-300)
    }

    /// トークンと有効期間（秒）から初期化
    /// - Parameters:
    ///   - token: アクセストークン
    ///   - expiresIn: 有効期間（秒）
    init(token: String, expiresIn: Int) {
        self.token = token
        self.expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
    }
}
