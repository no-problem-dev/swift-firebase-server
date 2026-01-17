import Foundation

/// CloudEvents 仕様に基づくHTTPヘッダー
///
/// Google Cloud Eventarc は CloudEvents 形式でイベントを送信します。
/// このプロトコルはWebhookヘッダーからCloudEventメタデータを抽出します。
///
/// ## CloudEvents 仕様
/// - `ce-type`: イベントタイプ（例: `google.firebase.auth.user.v1.created`）
/// - `ce-source`: イベントソース（例: `//firebaseauth.googleapis.com/projects/my-project`）
/// - `ce-id`: イベントID（UUID）
/// - `ce-time`: イベント発生時刻（RFC3339形式）
/// - `ce-subject`: イベント対象（オプション）
/// - `ce-specversion`: CloudEvents仕様バージョン（通常 "1.0"）
///
/// ## 参考
/// - [CloudEvents Spec](https://cloudevents.io/)
/// - [Eventarc CloudEvents](https://cloud.google.com/eventarc/docs/cloudevents)
public struct CloudEventHeaders: Sendable {
    /// イベントタイプ
    public let type: String?

    /// イベントソース
    public let source: String?

    /// イベントID
    public let id: String?

    /// イベント発生時刻（RFC3339形式）
    public let time: String?

    /// イベント対象
    public let subject: String?

    /// CloudEvents仕様バージョン
    public let specVersion: String?

    /// 生のヘッダー辞書
    private let rawHeaders: [String: String]

    /// ヘッダー辞書から初期化
    ///
    /// - Parameter headers: HTTPヘッダー辞書（小文字キー推奨）
    public init(from headers: [String: String]) {
        self.rawHeaders = headers
        self.type = headers["ce-type"]
        self.source = headers["ce-source"]
        self.id = headers["ce-id"]
        self.time = headers["ce-time"]
        self.subject = headers["ce-subject"]
        self.specVersion = headers["ce-specversion"]
    }

    /// 任意のヘッダー値を取得
    public subscript(_ key: String) -> String? {
        rawHeaders[key.lowercased()]
    }

    /// デバッグ用の説明文字列
    public var debugDescription: String {
        """
        CloudEventHeaders:
          type: \(type ?? "nil")
          source: \(source ?? "nil")
          id: \(id ?? "nil")
          time: \(time ?? "nil")
          subject: \(subject ?? "nil")
          specVersion: \(specVersion ?? "nil")
        """
    }
}

// MARK: - Firebase Auth Event Types

extension CloudEventHeaders {
    /// Firebase Auth イベントタイプ
    public enum AuthEventType {
        /// ユーザー作成イベント
        public static let userCreated = "google.firebase.auth.user.v1.created"
        /// ユーザー削除イベント
        public static let userDeleted = "google.firebase.auth.user.v1.deleted"
    }
}

// MARK: - Firestore Event Types

extension CloudEventHeaders {
    /// Firestore イベントタイプ
    public enum FirestoreEventType {
        /// ドキュメント作成イベント
        public static let documentCreated = "google.cloud.firestore.document.v1.created"
        /// ドキュメント更新イベント
        public static let documentUpdated = "google.cloud.firestore.document.v1.updated"
        /// ドキュメント削除イベント
        public static let documentDeleted = "google.cloud.firestore.document.v1.deleted"
        /// ドキュメント書き込みイベント（作成・更新・削除のいずれか）
        public static let documentWritten = "google.cloud.firestore.document.v1.written"
    }
}
