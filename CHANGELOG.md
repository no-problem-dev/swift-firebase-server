# 変更履歴

このプロジェクトの全ての重要な変更はこのファイルに記録されます。

フォーマットは [Keep a Changelog](https://keepachangelog.com/ja/1.0.0/) に基づいており、
このプロジェクトは [セマンティックバージョニング](https://semver.org/lang/ja/spec/v2.0.0.html) に準拠しています。

## [未リリース]

## [1.0.1] - 2025-12-09

### 追加
- **FilterBuilder DSL** - ResultBuilderベースの宣言的フィルター構文
  - `Field` - フィールド参照と演算子オーバーロード（`==`, `!=`, `<`, `<=`, `>`, `>=`）
  - `And` / `Or` - 明示的な論理グループ化
  - `.contains()`, `.containsAny()`, `.in()`, `.notIn()` - 配列操作
  - `.isNull`, `.isNotNull`, `.isNaN`, `.isNotNaN` - NULL/NaN判定
  - `Query.filter { }` - DSLを使用したフィルター追加
- `FirestoreValueConvertible` - Swift標準型からFirestoreValueへの変換プロトコル

- **StorageServer** - Cloud Storage REST APIクライアント
  - `StorageClient` - アップロード、ダウンロード、削除、メタデータ取得
  - `StorageConfiguration` - 本番環境/エミュレーター対応
  - `StorageObject` - ファイルメタデータモデル
  - `StorageError` - 包括的なエラーハンドリング

- **StorageSchema マクロDSL** - 型安全なストレージスキーマ定義
  - `@StorageSchema` - ルートスキーマ定義マクロ
  - `@Folder("id")` - 階層的フォルダ構造定義
  - `@Object("id")` - ファイルオブジェクトパス定義
  - `FileExtension` - 一般的なファイル形式のContent-Typeマッピング
  - `StorageSchemaProtocol` / `StorageFolderProtocol` / `StorageObjectPathProtocol`

- **Internal（共有モジュール）**
  - `HTTPClientProvider` - 共有HTTPクライアント管理
  - `APIError` - Firebase REST API共通エラー
  - `ServiceConfiguration` プロトコルと `EmulatorConfig`

### 変更
- FirestoreServerをInternalモジュールを使用するようにリファクタリング
- `FirestoreError` が共通エラーケースで `APIError` をラップするように変更

### 削除
- `QueryResult<T>` - 未使用の構造体を削除

## [1.0.0] - 2025-12-09

### 追加
- **FirestoreServer コアライブラリ**
  - `FirestoreClient` - REST APIクライアント
  - `CollectionReference` / `DocumentReference` - 参照型
  - `CollectionPath` / `DocumentPath` / `DatabasePath` - パス型
  - `FirestoreEncoder` / `FirestoreDecoder` - Codable対応
  - `FirestoreValue` - Firestore値型のSwift表現

- **Query API**
  - `Query<T>` - 型安全なクエリビルダー
  - `FieldFilter` - フィールドフィルター（equal, lessThan, greaterThan, in, arrayContains等）
  - `CompositeFilter` - 複合フィルター（AND/OR）
  - `UnaryFilter` - 単項フィルター（isNull, isNotNull）
  - `QueryOrder` - ソート（ascending, descending）
  - ページネーション（limit, offset, startAt, startAfter, endAt, endBefore）

- **FirestoreSchema マクロDSL**
  - `@FirestoreSchema` - ルートスキーマ定義マクロ
  - `@Collection("id")` - コレクション定義マクロ
  - `@SubCollection("id")` - サブコレクション定義マクロ
  - `FirestoreSchemaProtocol` / `FirestoreCollectionProtocol` / `FirestoreDocumentProtocol` - プロトコル定義

### ドキュメント
- 包括的な README.md
- リリースプロセスガイド
- GitHub Actions による DocC 自動デプロイ

[1.0.1]: https://github.com/no-problem-dev/swift-firestore-server/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/no-problem-dev/swift-firestore-server/releases/tag/v1.0.0
