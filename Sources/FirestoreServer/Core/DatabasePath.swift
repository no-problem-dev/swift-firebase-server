/// Firestoreデータベースへのパス
///
/// REST APIのベースパスを構成する:
/// `projects/{projectId}/databases/{databaseId}/documents`
public struct DatabasePath: Sendable, Hashable {
    /// Google CloudプロジェクトID
    public let projectId: String

    /// データベースID（通常は "(default)"）
    public let databaseId: String

    /// 初期化
    /// - Parameters:
    ///   - projectId: Google CloudプロジェクトID
    ///   - databaseId: データベースID（デフォルト: "(default)"）
    public init(projectId: String, databaseId: String = "(default)") {
        self.projectId = projectId
        self.databaseId = databaseId
    }

    /// REST APIのドキュメントルートパス
    /// 例: `projects/my-project/databases/(default)/documents`
    public var documentsPath: String {
        "projects/\(projectId)/databases/\(databaseId)/documents"
    }
}

extension DatabasePath: CustomStringConvertible {
    public var description: String {
        documentsPath
    }
}
