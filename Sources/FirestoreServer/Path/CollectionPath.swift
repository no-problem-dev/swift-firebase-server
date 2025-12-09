/// コレクションへのパス
///
/// コレクションはドキュメントのコンテナであり、パスは奇数個のセグメントで構成される。
///
/// 例:
/// - `users` (ルートコレクション)
/// - `users/abc123/books` (サブコレクション)
/// - `users/abc123/books/xyz/chapters` (ネストしたサブコレクション)
public struct CollectionPath: Sendable, Hashable {
    public let segments: [PathSegment]

    /// セグメント配列から初期化（内部用）
    internal init(segments: [PathSegment]) {
        precondition(segments.count % 2 == 1, "Collection path must have odd number of segments")
        self.segments = segments
    }

    /// 文字列パスから初期化
    /// - Parameter path: スラッシュ区切りのパス文字列
    /// - Throws: パスがコレクションとして無効な場合
    public init(_ path: String) throws(PathError) {
        let resource = try ResourcePath(path)
        guard resource.isCollection else {
            throw .invalidCollectionPath(path)
        }
        self.segments = resource.segments
    }

    /// コレクションID（最後のセグメント）
    public var collectionId: String {
        segments.last!.id
    }

    /// 親ドキュメントのパス（ルートコレクションの場合はnil）
    public var parent: DocumentPath? {
        guard segments.count > 1 else { return nil }
        return DocumentPath(segments: Array(segments.dropLast()))
    }

    /// このコレクション内のドキュメントへのパスを生成
    /// - Parameter documentId: ドキュメントID
    /// - Returns: ドキュメントパス
    public func document(_ documentId: String) -> DocumentPath {
        DocumentPath(segments: segments + [.document(documentId)])
    }

    /// 文字列表現
    public var rawValue: String {
        segments.map(\.id).joined(separator: "/")
    }
}

extension CollectionPath: CustomStringConvertible {
    public var description: String {
        rawValue
    }
}
