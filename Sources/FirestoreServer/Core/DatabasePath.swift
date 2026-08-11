/// Identifies one Firestore database.
///
/// Every REST path in this package is built on top of it:
/// `projects/{projectId}/databases/{databaseId}/documents`.
public struct DatabasePath: Sendable, Hashable {
    public let projectId: String

    /// The Firestore database ID, `"(default)"` unless the project uses a named database.
    public let databaseId: String

    /// - Parameters:
    ///   - projectId: The Google Cloud project ID.
    ///   - databaseId: The Firestore database ID.
    public init(projectId: String, databaseId: String = "(default)") {
        self.projectId = projectId
        self.databaseId = databaseId
    }

    /// The REST resource name of the database's document root.
    ///
    /// For example: `projects/my-project/databases/(default)/documents`. The value is
    /// interpolated into request URLs as-is, parentheses and all, without percent-encoding.
    public var documentsPath: String {
        "projects/\(projectId)/databases/\(databaseId)/documents"
    }
}

extension DatabasePath: CustomStringConvertible {
    public var description: String {
        documentsPath
    }
}
