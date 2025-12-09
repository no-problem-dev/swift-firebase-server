/// パス関連のエラー
public enum PathError: Error, Sendable, Hashable {
    /// パスが空
    case emptyPath

    /// コレクションパスとして無効（偶数個のセグメント）
    case invalidCollectionPath(String)

    /// ドキュメントパスとして無効（奇数個のセグメント）
    case invalidDocumentPath(String)

    /// パスに無効な文字が含まれている
    case invalidCharacters(String)
}

extension PathError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .emptyPath:
            return "Path cannot be empty"
        case .invalidCollectionPath(let path):
            return "Invalid collection path: '\(path)' (must have odd number of segments)"
        case .invalidDocumentPath(let path):
            return "Invalid document path: '\(path)' (must have even number of segments >= 2)"
        case .invalidCharacters(let path):
            return "Path contains invalid characters: '\(path)'"
        }
    }
}
