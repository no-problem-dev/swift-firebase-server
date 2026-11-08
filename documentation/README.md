# swift-firebase-server ドキュメント

サーバーサイドSwift向けFirebase REST APIクライアントの詳細ドキュメント。

## ガイド

### はじめに

- **[クイックスタート](getting-started.md)** - 5分でセットアップ

### Firestore

- **[スキーマ定義](firestore/schema-definition.md)** - `@FirestoreSchema`, `@Collection` マクロ
- **[モデル定義](firestore/model-definition.md)** - `@FirestoreModel`, `@Field`, `@FieldIgnore` マクロ
- **[ドキュメント操作](firestore/document-operations.md)** - CRUD操作
- **[クエリ](firestore/queries.md)** - フィルター、ソート、ページネーション

### Cloud Storage

- **[スキーマ定義](storage/schema-definition.md)** - `@StorageSchema`, `@Folder`, `@Object` マクロ
- **[ファイル操作](storage/file-operations.md)** - アップロード/ダウンロード

### Firebase Auth

- **[トークン検証](auth/token-verification.md)** - IDトークン検証、ミドルウェア実装

## リファレンス

### Swift Macro

- **[Swift Macro リファレンス](references/macros/README.md)** - マクロの包括的なリファレンス
  - [Freestanding Macro](references/macros/freestanding-macros.md) - 独立型マクロ（Expression, Declaration）
  - [Attached Macro](references/macros/attached-macros.md) - 付与型マクロ（Member, Peer, Accessor等）
  - [パッケージ構成](references/macros/package-structure.md) - Package.swift、プラグイン登録
  - [SwiftSyntax API](references/macros/swiftsyntax-api.md) - 構文木の操作
  - [診断とエラー](references/macros/diagnostics.md) - エラーメッセージ、Fix-It
  - [テスト手法](references/macros/testing.md) - assertMacroExpansion

## APIリファレンス（DocC）

- [FirestoreServer](../Sources/FirestoreServer/Documentation.docc)
- [FirestoreSchema](../Sources/FirestoreSchema/Documentation.docc)
- [FirebaseStorageServer](../Sources/FirebaseStorageServer/Documentation.docc)
- [FirebaseStorageSchema](../Sources/FirebaseStorageSchema/Documentation.docc)
- [FirebaseAuthServer](../Sources/FirebaseAuthServer/Documentation.docc)
