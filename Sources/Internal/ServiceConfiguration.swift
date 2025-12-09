import Foundation

/// Firebase サービス共通の設定プロトコル
public protocol ServiceConfiguration: Sendable {
    /// Google Cloud プロジェクトID
    var projectId: String { get }

    /// ベースURL（本番 or エミュレーター）
    var baseURL: URL { get }

    /// リクエストタイムアウト（秒）
    var timeout: TimeInterval { get }
}

/// エミュレーター設定を持つサービス用プロトコル
public protocol EmulatorConfigurable {
    /// エミュレーター用の設定を作成
    /// - Parameters:
    ///   - projectId: Google CloudプロジェクトID
    ///   - host: エミュレーターホスト
    ///   - port: エミュレーターポート
    ///   - timeout: タイムアウト秒数
    static func emulator(
        projectId: String,
        host: String,
        port: Int,
        timeout: TimeInterval
    ) -> Self
}

/// 共通のエミュレーター設定
public struct EmulatorConfig: Sendable {
    /// ホスト名
    public let host: String

    /// ポート番号
    public let port: Int

    /// デフォルトのFirestoreエミュレーターポート
    public static let defaultFirestorePort = 8080

    /// デフォルトのStorageエミュレーターポート
    public static let defaultStoragePort = 9199

    /// デフォルトホスト
    public static let defaultHost = "localhost"

    public init(host: String = Self.defaultHost, port: Int) {
        self.host = host
        self.port = port
    }

    /// ベースURLを構築
    /// - Parameter path: URLパス（例: "/v1"）
    public func buildURL(path: String = "") -> URL {
        URL(string: "http://\(host):\(port)\(path)")!
    }
}
