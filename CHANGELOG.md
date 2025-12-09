# 変更履歴

このプロジェクトの全ての重要な変更はこのファイルに記録されます。

フォーマットは [Keep a Changelog](https://keepachangelog.com/ja/1.0.0/) に基づいており、
このプロジェクトは [セマンティックバージョニング](https://semver.org/lang/ja/spec/v2.0.0.html) に準拠しています。

## [未リリース]

なし

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

[未リリース]: https://github.com/no-problem-dev/swift-firestore-server/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/no-problem-dev/swift-firestore-server/releases/tag/v1.0.0
