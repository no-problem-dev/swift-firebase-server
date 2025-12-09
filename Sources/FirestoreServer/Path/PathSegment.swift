/// Firestoreパスの構成要素
///
/// Firestoreのパスは `collection/document/collection/document/...` の形式で、
/// 奇数番目がコレクション、偶数番目がドキュメントを表す。
public enum PathSegment: Sendable, Hashable {
    case collection(String)
    case document(String)

    public var id: String {
        switch self {
        case .collection(let id), .document(let id):
            return id
        }
    }

    public var isCollection: Bool {
        if case .collection = self { return true }
        return false
    }

    public var isDocument: Bool {
        if case .document = self { return true }
        return false
    }
}
