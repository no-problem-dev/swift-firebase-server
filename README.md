# swift-firestore-server

サーバーサイドSwift向けFirestore REST APIクライアント

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-macOS%2014+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

📚 **[APIリファレンス（DocC）](https://no-problem-dev.github.io/swift-firestore-server/documentation/firestoreserver/)**

## 特徴

```swift
import FirestoreServer
import FirestoreSchema

// マクロベースの型安全なスキーマ定義
@FirestoreSchema
struct AppSchema {
    @Collection("users")
    struct Users {
        @SubCollection("books")
        struct Books {}
    }
}

// Fluent APIでドキュメントにアクセス
let client = FirestoreClient(projectId: "my-project", accessToken: token)
let schema = AppSchema(client: client)

// ドキュメントの取得
let user: User = try await schema.users("userId").get()

// クエリの実行
let activeUsers = try await schema.users.query(as: User.self)
    .where("status", .equal, "active")
    .orderBy("createdAt", .descending)
    .limit(10)
    .get()
```

- **Vapor非依存** - AsyncHTTPClientベースで軽量
- **マクロベースDSL** - `@FirestoreSchema`、`@Collection`、`@SubCollection`で型安全なアクセス
- **REST API完全対応** - Firebase Admin SDK不要でサーバーサイドから直接アクセス
- **Swift Concurrency** - async/awaitによる非同期API
- **型安全なクエリ** - フィルター、ソート、ページネーションをtype-safeに構築
- **Codable統合** - カスタムEncoder/DecoderでFirestore値型に対応

## インストール

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-firestore-server.git", .upToNextMajor(from: "1.0.0"))
]

// ターゲットに追加
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "FirestoreServer", package: "swift-firestore-server"),
        .product(name: "FirestoreSchema", package: "swift-firestore-server"),
    ]
)
```

## 基本的な使い方

### 1. スキーマの定義

```swift
import FirestoreSchema

@FirestoreSchema
struct AppSchema {
    @Collection("users")
    struct Users {
        @SubCollection("posts")
        struct Posts {}
    }

    @Collection("products")
    struct Products {}
}
```

### 2. クライアントの初期化

```swift
import FirestoreServer

// Google Cloud認証トークンを使用
let client = FirestoreClient(
    projectId: "your-project-id",
    accessToken: accessToken
)

// カスタムデータベースID（オプション）
let client = FirestoreClient(
    projectId: "your-project-id",
    databaseId: "custom-db",
    accessToken: accessToken
)
```

### 3. ドキュメント操作

```swift
let schema = AppSchema(client: client)

// ドキュメント取得
let user: User = try await schema.users("userId").get()

// ドキュメント作成（IDを指定）
try await schema.users("newUserId").set(newUser)

// ドキュメント作成（ID自動生成）
let docId = try await schema.users.add(newUser)

// ドキュメント更新
try await schema.users("userId").update(["name": "New Name"])

// ドキュメント削除
try await schema.users("userId").delete()
```

### 4. サブコレクションへのアクセス

```swift
// ユーザーの投稿を取得
let posts: [Post] = try await schema.users("userId").posts
    .query(as: Post.self)
    .get()

// 投稿を追加
try await schema.users("userId").posts("postId").set(newPost)
```

### 5. クエリ

```swift
// 条件付きクエリ
let activeUsers = try await schema.users
    .query(as: User.self)
    .where("status", .equal, "active")
    .where("age", .greaterThanOrEqual, 18)
    .orderBy("createdAt", .descending)
    .limit(20)
    .get()

// 複合フィルター（AND）
let results = try await schema.products
    .query(as: Product.self)
    .where(.and([
        .field("category", .equal, "electronics"),
        .field("price", .lessThan, 1000)
    ]))
    .get()

// 複合フィルター（OR）
let results = try await schema.products
    .query(as: Product.self)
    .where(.or([
        .field("status", .equal, "sale"),
        .field("featured", .equal, true)
    ]))
    .get()

// ページネーション
let (users, nextCursor) = try await schema.users
    .query(as: User.self)
    .orderBy("createdAt")
    .limit(10)
    .startAfter(cursor)
    .getWithCursor()
```

## 低レベルAPI

マクロを使わない場合、`CollectionReference`と`DocumentReference`を直接使用できます：

```swift
// コレクション参照
let usersRef = client.collection("users")
let user: User = try await client.getDocument(usersRef.document("userId"))

// クエリ
let query = usersRef.query(as: User.self)
    .where("active", .equal, true)
let users = try await client.runQuery(query)
```

## Firestoreの値型

Firestore REST APIの値型に対応したカスタムEncoder/Decoderを提供：

| Swift型 | Firestore値型 |
|---------|---------------|
| `String` | `stringValue` |
| `Int`, `Int64` | `integerValue` |
| `Double`, `Float` | `doubleValue` |
| `Bool` | `booleanValue` |
| `Date` | `timestampValue` |
| `Data` | `bytesValue` |
| `[T]` | `arrayValue` |
| `[String: T]` | `mapValue` |
| `nil` | `nullValue` |
| `GeoPoint` | `geoPointValue` |
| `DocumentReference` | `referenceValue` |

## 要件

- macOS 14+
- Swift 6.2+
- Xcode 16+

## ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照

## 開発者向け情報

- 🚀 **リリース作業**: [リリースプロセス](RELEASE_PROCESS.md) - 新バージョンをリリースする手順

## サポート

- 📚 [APIリファレンス（DocC）](https://no-problem-dev.github.io/swift-firestore-server/documentation/firestoreserver/)
- 🐛 [Issue報告](https://github.com/no-problem-dev/swift-firestore-server/issues)
- 💬 [ディスカッション](https://github.com/no-problem-dev/swift-firestore-server/discussions)

---

Made with ❤️ by [NOPROBLEM](https://github.com/no-problem-dev)
