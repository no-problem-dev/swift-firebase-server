import Foundation

/// GCP認証・環境設定
///
/// Firebase サービスへの接続方法を排他的に指定する。
/// 各ケースは必要な認証情報の組み合わせが異なる。
///
/// 使用例:
/// ```swift
/// // Cloud Run / ローカル gcloud: 全自動
/// let firestore = try await FirestoreClient(config: .auto)
///
/// // エミュレーター: projectIdのみ指定
/// let firestore = FirestoreClient(config: .emulator(projectId: "demo-project"))
///
/// // 明示指定: 両方渡す（テストやカスタム認証フロー）
/// let firestore = FirestoreClient(config: .explicit(projectId: "my-project", token: accessToken))
/// ```
public enum GCPConfiguration: Sendable {
    /// 自動検出モード
    ///
    /// 環境に応じて認証情報を自動取得する:
    /// - Cloud Run: メタデータサーバーから projectId, token を取得
    /// - ローカル: gcloud CLI から projectId, token を取得
    ///
    /// - Note: このモードでは初期化が async になる
    case auto

    /// 自動検出モード（databaseId指定）
    ///
    /// Firestoreで "(default)" 以外のデータベースを使用する場合に指定
    case autoWithDatabase(databaseId: String)

    /// エミュレーターモード
    ///
    /// Firebase Emulator Suite に接続する。
    /// 認証トークンは不要（ダミートークン "owner" を使用）。
    ///
    /// - Parameter projectId: プロジェクトID（任意の値でOK、例: "demo-project"）
    case emulator(projectId: String)

    /// 明示指定モード
    ///
    /// projectId と認証トークンを外部から直接渡す。
    /// ユーザーのIDトークンを使用したアクセスや、
    /// 独自の認証フローを使用する場合に利用。
    ///
    /// - Parameters:
    ///   - projectId: Google Cloud プロジェクトID
    ///   - token: 認証トークン（Bearer トークン）
    case explicit(projectId: String, token: String)

    // MARK: - Computed Properties

    /// databaseId を取得（Firestore用）
    var databaseId: String {
        switch self {
        case .autoWithDatabase(let databaseId):
            return databaseId
        default:
            return "(default)"
        }
    }

    /// エミュレーターモードかどうか
    var isEmulator: Bool {
        switch self {
        case .emulator:
            return true
        default:
            return false
        }
    }

    /// 自動検出モードかどうか
    var isAuto: Bool {
        switch self {
        case .auto, .autoWithDatabase:
            return true
        default:
            return false
        }
    }
}

// MARK: - Resolved Configuration

/// 解決済みの認証情報
///
/// `GCPConfiguration` から実際の値を解決した結果。
/// auto モードの場合は環境から取得した値、
/// explicit モードの場合は指定された値が入る。
public struct ResolvedGCPConfiguration: Sendable {
    /// プロジェクトID
    public let projectId: String

    /// 認証トークン
    public let token: String

    /// データベースID（Firestore用）
    public let databaseId: String

    /// エミュレーターモードかどうか
    public let isEmulator: Bool

    public init(
        projectId: String,
        token: String,
        databaseId: String = "(default)",
        isEmulator: Bool = false
    ) {
        self.projectId = projectId
        self.token = token
        self.databaseId = databaseId
        self.isEmulator = isEmulator
    }
}
