/// Firestoreリソースへのパス（コレクションまたはドキュメント）
///
/// Firestoreのデータ構造:
/// - コレクション: ドキュメントのコンテナ（奇数個のセグメント）
/// - ドキュメント: フィールドを持つ実体（偶数個のセグメント）
/// - サブコレクション: ドキュメント配下のコレクション
///
/// 例:
/// - `users` → コレクション (1セグメント)
/// - `users/abc123` → ドキュメント (2セグメント)
/// - `users/abc123/books` → サブコレクション (3セグメント)
/// - `users/abc123/books/xyz` → ドキュメント (4セグメント)
public struct ResourcePath: Sendable, Hashable {
    public let segments: [PathSegment]

    /// セグメント配列から初期化
    internal init(segments: [PathSegment]) {
        self.segments = segments
    }

    /// 文字列パスからパース
    /// - Parameter path: スラッシュ区切りのパス文字列
    /// - Throws: パスが空の場合
    public init(_ path: String) throws(PathError) {
        let parts = path.split(separator: "/").map(String.init)
        guard !parts.isEmpty else {
            throw .emptyPath
        }

        // 交互にcollection/documentとして解釈
        var segments: [PathSegment] = []
        for (index, part) in parts.enumerated() {
            if index % 2 == 0 {
                segments.append(.collection(part))
            } else {
                segments.append(.document(part))
            }
        }
        self.segments = segments
    }

    /// パスがコレクションを指しているか
    public var isCollection: Bool {
        segments.count % 2 == 1
    }

    /// パスがドキュメントを指しているか
    public var isDocument: Bool {
        segments.count % 2 == 0 && !segments.isEmpty
    }

    /// コレクションパスに変換（コレクションの場合のみ）
    public func asCollection() -> CollectionPath? {
        guard isCollection else { return nil }
        return CollectionPath(segments: segments)
    }

    /// ドキュメントパスに変換（ドキュメントの場合のみ）
    public func asDocument() -> DocumentPath? {
        guard isDocument else { return nil }
        return DocumentPath(segments: segments)
    }

    /// 文字列表現
    public var rawValue: String {
        segments.map(\.id).joined(separator: "/")
    }
}

extension ResourcePath: CustomStringConvertible {
    public var description: String {
        rawValue
    }
}
