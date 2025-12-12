# swift-firebase-server

サーバーサイドSwift向けFirebase REST APIクライアント（Firestore & Cloud Storage & Auth）

🌐 **[English](README_EN.md)** | 日本語

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-macOS%2014+-blue.svg)
![License](https://img.shields.io/badge/License-MIT.svg)

## できること

- Firestore のドキュメント CRUD 操作
- Cloud Storage のファイルアップロード・ダウンロード
- Firebase Auth の ID トークン検証
- 型安全なコレクションパス生成
- 宣言的なクエリ構築

## 特徴

- **Swift Macro DSL** - `@FirestoreSchema`、`@Collection`、`@FirestoreModel` で型安全なスキーマとモデルを定義
- **CodingKeys 自動生成** - `@FirestoreModel` で `snakeCase` 変換や `@Field` カスタムキーに対応
- **REST API ネイティブ** - Firebase Admin SDK 不要、サーバーサイド Swift から直接アクセス
- **FilterBuilder DSL** - Result Builder による宣言的なクエリ構文

## クイックスタート

```swift
import FirestoreServer
import FirestoreSchema

@FirestoreModel(keyStrategy: .snakeCase)
struct User {
    let id: String
    let displayName: String
    let email: String
}

@FirestoreSchema
struct Schema {
    @Collection("users", model: User.self)
    enum Users {
        @Collection("posts", model: Post.self)
        enum Posts {}
    }
}

// Cloud Run / ローカル gcloud 自動検出
let client = try await FirestoreClient(.auto)
let schema = Schema(client: client)

// ドキュメント取得（型推論が効く）
let user = try await schema.users.document("user123").get()

// ドキュメント作成
try await schema.users.document("user123").create(data: newUser)

// クエリ実行
let activeUsers = try await schema.users.execute(
    schema.users.query().filter { Field("status") == "active" }
)
```

## インストール

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-firebase-server.git", .upToNextMajor(from: "1.0.0"))
]

.target(
    name: "YourApp",
    dependencies: [
        .product(name: "FirestoreServer", package: "swift-firebase-server"),
        .product(name: "FirestoreSchema", package: "swift-firebase-server"),
        .product(name: "FirebaseStorageServer", package: "swift-firebase-server"),
        .product(name: "FirebaseStorageSchema", package: "swift-firebase-server"),
        .product(name: "FirebaseAuthServer", package: "swift-firebase-server"),
    ]
)
```

## ドキュメント

### 📖 使用ガイド

| ガイド | 説明 |
|--------|------|
| [はじめに](documentation/getting-started.md) | 環境構築とクイックスタート |
| [Firestore ドキュメント操作](documentation/firestore/document-operations.md) | CRUD操作 |
| [Firestore クエリ](documentation/firestore/queries.md) | フィルター、ソート、ページネーション |
| [Firestore スキーマ定義](documentation/firestore/schema-definition.md) | @FirestoreSchema マクロ |
| [Firestore モデル定義](documentation/firestore/model-definition.md) | @FirestoreModel マクロ |
| [Storage ファイル操作](documentation/storage/file-operations.md) | アップロード・ダウンロード |
| [Storage スキーマ定義](documentation/storage/schema-definition.md) | @StorageSchema マクロ |
| [Auth トークン検証](documentation/auth/token-verification.md) | IDトークン検証 |

### 📚 APIリファレンス（DocC）

- [FirestoreServer](https://no-problem-dev.github.io/swift-firebase-server/firestoreserver/documentation/firestoreserver/) - Firestore REST API クライアント
- [FirestoreSchema](https://no-problem-dev.github.io/swift-firebase-server/firestoreschema/documentation/firestoreschema/) - 型安全なスキーマ DSL
- [FirebaseStorageServer](https://no-problem-dev.github.io/swift-firebase-server/firebasestorageserver/documentation/firebasestorageserver/) - Cloud Storage クライアント
- [FirebaseStorageSchema](https://no-problem-dev.github.io/swift-firebase-server/firebasestorageschema/documentation/firebasestorageschema/) - 型安全な Storage スキーマ DSL
- [FirebaseAuthServer](https://no-problem-dev.github.io/swift-firebase-server/firebaseauthserver/documentation/firebaseauthserver/) - ID トークン検証

### 🔧 技術リファレンス

- [Swift Macro リファレンス](documentation/references/macros/README.md) - マクロの包括的なリファレンス

## 要件

- macOS 14+
- Swift 6.2+
- Xcode 16+

## ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照

## 開発者向け情報

- 🚀 **リリース作業**: [リリースプロセス](RELEASE_PROCESS.md)

## サポート

- 🐛 [Issue報告](https://github.com/no-problem-dev/swift-firebase-server/issues)
- 💬 [ディスカッション](https://github.com/no-problem-dev/swift-firebase-server/discussions)

---

Made with ❤️ by [NOPROBLEM](https://github.com/no-problem-dev)
