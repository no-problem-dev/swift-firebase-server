/// ドキュメントへのパス
///
/// ドキュメントはフィールドを持つデータの実体であり、パスは偶数個のセグメントで構成される。
/// ドキュメントはサブコレクションを持つことができる。
///
/// 例:
/// - `users/abc123`
/// - `users/abc123/books/xyz`
/// - `users/abc123/books/xyz/chapters/ch1`
public struct DocumentPath: Sendable, Hashable {
    public let segments: [PathSegment]

    /// セグメント配列から初期化（内部用）
    internal init(segments: [PathSegment]) {
        precondition(segments.count >= 2 && segments.count % 2 == 0,
                     "Document path must have even number of segments (>= 2)")
        self.segments = segments
    }

    /// 文字列パスから初期化
    /// - Parameter path: スラッシュ区切りのパス文字列
    /// - Throws: パスがドキュメントとして無効な場合
    public init(_ path: String) throws(PathError) {
        let resource = try ResourcePath(path)
        guard resource.isDocument else {
            throw .invalidDocumentPath(path)
        }
        self.segments = resource.segments
    }

    /// ドキュメントID（最後のセグメント）
    public var documentId: String {
        segments.last!.id
    }

    /// 親コレクションのパス
    public var parent: CollectionPath {
        CollectionPath(segments: Array(segments.dropLast()))
    }

    /// このドキュメント配下のサブコレクションへのパスを生成
    /// - Parameter collectionId: コレクションID
    /// - Returns: コレクションパス
    public func collection(_ collectionId: String) -> CollectionPath {
        CollectionPath(segments: segments + [.collection(collectionId)])
    }

    /// 文字列表現
    public var rawValue: String {
        segments.map(\.id).joined(separator: "/")
    }
}

extension DocumentPath: CustomStringConvertible {
    public var description: String {
        rawValue
    }
}
