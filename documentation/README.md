# swift-firebase-server ドキュメント

サーバーサイドSwift向けFirebase REST APIクライアントの詳細ドキュメントです。

## ガイド

### はじめに

- **[クイックスタート](getting-started.md)** - 5分でセットアップ

### Firestore

- **[スキーマ定義](firestore/schema-definition.md)** - `@FirestoreSchema`, `@Collection` マクロ
- **[モデル定義](firestore/model-definition.md)** - `@FirestoreModel`, `@Field`, `@FieldIgnore` マクロ
- **[ドキュメント操作](firestore/document-operations.md)** - CRUD操作
- **[クエリ](firestore/queries.md)** - フィルター、ソート、ページネーション
- **[FilterBuilder DSL](firestore/filter-builder-dsl.md)** - 宣言的なフィルター構文

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

- [FirestoreServer](https://no-problem-dev.github.io/swift-firebase-server/firestoreserver/documentation/firestoreserver/)
- [FirestoreSchema](https://no-problem-dev.github.io/swift-firebase-server/firestoreschema/documentation/firestoreschema/)
- [FirebaseStorageServer](https://no-problem-dev.github.io/swift-firebase-server/firebasestorageserver/documentation/firebasestorageserver/)
- [FirebaseStorageSchema](https://no-problem-dev.github.io/swift-firebase-server/firebasestorageschema/documentation/firebasestorageschema/)
- [FirebaseAuthServer](https://no-problem-dev.github.io/swift-firebase-server/firebaseauthserver/documentation/firebaseauthserver/)
