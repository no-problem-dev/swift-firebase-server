# swift-firebase-server

サーバーサイドSwift向けFirebase REST APIクライアント（Firestore & Cloud Storage & Auth）

🌐 **[English](README_EN.md)** | 日本語

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-macOS%2014+-blue.svg)
![License](https://img.shields.io/badge/License-MIT.svg)

## 特徴

- **Swift Macro DSL** - `@FirestoreSchema`、`@Collection`、`@FirestoreModel` で型安全なスキーマとモデルを定義
- **CodingKeys 自動生成** - `@FirestoreModel` で `snakeCase` 変換や `@Field` カスタムキーに対応
- **REST API ネイティブ** - Firebase Admin SDK 不要、サーバーサイド Swift から直接アクセス
- **FilterBuilder DSL** - Result Builder による宣言的なクエリ構文

## クイックスタート

```swift
import FirestoreServer
import FirestoreSchema

// モデル定義（CodingKeys自動生成）
@FirestoreModel(keyStrategy: .snakeCase)
struct User {
    let id: String
    let displayName: String  // → display_name
    let email: String
}

// スキーマ定義（enumで型安全なパス構築）
@FirestoreSchema
enum Schema {
    @Collection("users", model: User.self)
    enum Users {
        @Collection("posts", model: Post.self)
        enum Posts {}
    }
}

// パス生成
Schema.Users.collectionPath                    // "users"
Schema.Users.documentPath("user123")           // "users/user123"
Schema.Users.Posts.collectionPath("user123")   // "users/user123/posts"

// クライアント操作
let client = FirestoreClient(projectId: "my-project")
let userRef = try client.document(Schema.Users.documentPath("user123"))
let user: User = try await client.getDocument(userRef, as: User.self, authorization: idToken)
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
| [はじめに](docs/getting-started.md) | 環境構築とクイックスタート |
| [Firestore ドキュメント操作](docs/firestore/document-operations.md) | CRUD操作 |
| [Firestore クエリ](docs/firestore/queries.md) | 条件付き検索 |
| [Firestore FilterBuilder DSL](docs/firestore/filter-builder-dsl.md) | 宣言的フィルター構文 |
| [Firestore スキーマ定義](docs/firestore/schema-definition.md) | @FirestoreSchema マクロ |
| [Firestore モデル定義](docs/firestore/model-definition.md) | @FirestoreModel マクロ |
| [Storage ファイル操作](docs/storage/file-operations.md) | アップロード・ダウンロード |
| [Storage スキーマ定義](docs/storage/schema-definition.md) | @StorageSchema マクロ |
| [Auth トークン検証](docs/auth/token-verification.md) | IDトークン検証 |

### 📚 APIリファレンス（DocC）

- [FirestoreServer](https://no-problem-dev.github.io/swift-firebase-server/firestoreserver/documentation/firestoreserver/) - Firestore REST API クライアント
- [FirestoreSchema](https://no-problem-dev.github.io/swift-firebase-server/firestoreschema/documentation/firestoreschema/) - 型安全なスキーマ DSL
- [FirebaseStorageServer](https://no-problem-dev.github.io/swift-firebase-server/firebasestorageserver/documentation/firebasestorageserver/) - Cloud Storage クライアント
- [FirebaseStorageSchema](https://no-problem-dev.github.io/swift-firebase-server/firebasestorageschema/documentation/firebasestorageschema/) - 型安全な Storage スキーマ DSL
- [FirebaseAuthServer](https://no-problem-dev.github.io/swift-firebase-server/firebaseauthserver/documentation/firebaseauthserver/) - ID トークン検証

### 🔧 技術リファレンス

- [Swift Macro リファレンス](docs/references/macros/README.md) - マクロの包括的なリファレンス
  - [Freestanding Macro](docs/references/macros/freestanding-macros.md) - 独立型マクロ（Expression, Declaration）
  - [Attached Macro](docs/references/macros/attached-macros.md) - 付与型マクロ（Member, Peer, Accessor等）
  - [パッケージ構成](docs/references/macros/package-structure.md) - Package.swift、プラグイン登録
  - [SwiftSyntax API](docs/references/macros/swiftsyntax-api.md) - 構文木の操作
  - [診断とエラー](docs/references/macros/diagnostics.md) - エラーメッセージ、Fix-It
  - [テスト手法](docs/references/macros/testing.md) - assertMacroExpansion

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
