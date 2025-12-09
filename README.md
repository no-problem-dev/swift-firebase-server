# swift-firebase-server

サーバーサイドSwift向けFirebase REST APIクライアント（Firestore & Cloud Storage & Auth）

🌐 **[English](README_EN.md)** | 日本語

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-macOS%2014+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

📚 **[APIリファレンス（DocC）](https://no-problem-dev.github.io/swift-firebase-server/documentation/firestoreserver/)**

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
- **Cloud Storage対応** - `@StorageSchema`、`@Folder`、`@Object`でファイルパスを型安全に構築
- **Firebase Auth対応** - IDトークン検証でサーバーサイド認証を実装
- **REST API完全対応** - Firebase Admin SDK不要でサーバーサイドから直接アクセス
- **Swift Concurrency** - async/awaitによる非同期API
- **型安全なクエリ** - フィルター、ソート、ページネーションをtype-safeに構築
- **Codable統合** - カスタムEncoder/DecoderでFirestore値型に対応

## インストール

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-firebase-server.git", .upToNextMajor(from: "1.0.0"))
]

// ターゲットに追加
.target(
    name: "YourApp",
    dependencies: [
        // Firestore
        .product(name: "FirestoreServer", package: "swift-firebase-server"),
        .product(name: "FirestoreSchema", package: "swift-firebase-server"),
        // Cloud Storage
        .product(name: "FirebaseStorageServer", package: "swift-firebase-server"),
        .product(name: "FirebaseStorageSchema", package: "swift-firebase-server"),
        // Firebase Auth
        .product(name: "FirebaseAuthServer", package: "swift-firebase-server"),
    ]
)
```

## Firestore

#### 1. スキーマの定義

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

#### 2. クライアントの初期化

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

#### 3. ドキュメント操作

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

#### 4. サブコレクションへのアクセス

```swift
// ユーザーの投稿を取得
let posts: [Post] = try await schema.users("userId").posts
    .query(as: Post.self)
    .get()

// 投稿を追加
try await schema.users("userId").posts("postId").set(newPost)
```

#### 5. クエリ

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

#### 6. FilterBuilder DSL

ResultBuilderベースの宣言的なフィルター構文：

```swift
// 単一条件
let activeUsers = try await schema.users
    .query(as: User.self)
    .filter {
        Field("status") == "active"
    }
    .get()

// 複数条件（明示的なAnd）
let verifiedAdults = try await schema.users
    .query(as: User.self)
    .filter {
        And {
            Field("status") == "active"
            Field("age") >= 18
            Field("verified") == true
        }
    }
    .get()

// OR条件
let admins = try await schema.users
    .query(as: User.self)
    .filter {
        Or {
            Field("role") == "admin"
            Field("role") == "moderator"
        }
    }
    .get()

// ネストした条件
let featuredProducts = try await schema.products
    .query(as: Product.self)
    .filter {
        And {
            Field("active") == true
            Field("stock") > 0
            Or {
                Field("category") == "electronics"
                Field("featured") == true
            }
        }
    }
    .get()

// 条件分岐
let users = try await schema.users
    .query(as: User.self)
    .filter {
        And {
            Field("status") == "active"
            if onlyVerified {
                Field("verified") == true
            }
        }
    }
    .get()
```

**利用可能な演算子:**
- 比較: `==`, `!=`, `<`, `<=`, `>`, `>=`
- 配列: `.contains()`, `.containsAny()`, `.in()`, `.notIn()`
- NULL: `.isNull`, `.isNotNull`, `.isNaN`, `.isNotNaN`

#### 低レベルAPI

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

#### Firestoreの値型

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

## Cloud Storage

Cloud Storage REST APIクライアント。マクロベースの型安全なパス構築をサポートします。

#### 1. スキーマの定義

```swift
import FirebaseStorageSchema

@StorageSchema
struct AppStorage {
    @Folder("images")
    struct Images {
        @Folder("users")
        struct Users {
            @Object("profile")
            struct Profile {}

            @Object("avatar")
            struct Avatar {}
        }

        @Folder("products")
        struct Products {
            @Object("thumbnail")
            struct Thumbnail {}
        }
    }

    @Folder("documents")
    struct Documents {
        @Object("report")
        struct Report {}
    }
}
```

#### 2. クライアントの初期化

```swift
import FirebaseStorageServer

// 本番環境
let client = StorageClient(
    projectId: "your-project-id",
    bucket: "your-bucket.appspot.com"
)

// エミュレーター
let config = StorageConfiguration.emulator(
    projectId: "your-project-id",
    bucket: "your-bucket"
)
let client = StorageClient(configuration: config)
```

#### 3. 型安全なパス構築

```swift
let storage = AppStorage(client: client)

// パス生成: "images/users/user123.jpg"
let profilePath = storage.images.users.profile("user123", .jpg)

// パス生成: "images/products/prod456.png"
let thumbnailPath = storage.images.products.thumbnail("prod456", .png)

// パス生成: "documents/report001.pdf"
let reportPath = storage.documents.report("report001", .pdf)
```

#### 4. ファイル操作

```swift
let path = storage.images.users.profile("user123", .jpg)

// アップロード
let object = try await path.upload(
    data: imageData,
    authorization: token
)

// ダウンロード
let data = try await path.download(authorization: token)

// メタデータ取得
let metadata = try await path.getMetadata(authorization: token)

// 削除
try await path.delete(authorization: token)

// 公開URL取得
let url = path.publicURL
```

#### 低レベルAPI

マクロを使わない場合、`StorageClient`を直接使用できます：

```swift
let client = StorageClient(projectId: "my-project", bucket: "my-bucket")

// アップロード
let object = try await client.upload(
    data: imageData,
    path: "images/photo.jpg",
    contentType: "image/jpeg",
    authorization: token
)

// ダウンロード
let data = try await client.download(
    path: "images/photo.jpg",
    authorization: token
)

// 削除
try await client.delete(path: "images/photo.jpg", authorization: token)

// 公開URL
let url = client.publicURL(for: "images/photo.jpg")
```

#### 対応ファイル形式

`FileExtension` enumで一般的なファイル形式とContent-Typeの対応を提供：

| カテゴリ | 拡張子 |
|---------|--------|
| 画像 | `.jpg`, `.jpeg`, `.png`, `.gif`, `.webp`, `.heic`, `.svg`, `.bmp` |
| ドキュメント | `.pdf`, `.doc`, `.docx`, `.xls`, `.xlsx`, `.ppt`, `.pptx`, `.txt`, `.csv` |
| 動画 | `.mp4`, `.mov`, `.avi`, `.mkv`, `.webm` |
| 音声 | `.mp3`, `.wav`, `.aac`, `.m4a`, `.ogg`, `.flac` |
| データ | `.json`, `.xml`, `.yaml` |
| アーカイブ | `.zip`, `.tar`, `.gz`, `.rar` |

## Firebase Auth

Firebase IDトークン検証クライアント。クライアントから送信されたIDトークンを検証し、ユーザーを認証します。

#### 1. クライアントの初期化

```swift
import FirebaseAuthServer

// 本番環境
let authClient = AuthClient(projectId: "your-project-id")

// エミュレーター
let config = AuthConfiguration.emulator(projectId: "your-project-id")
let authClient = AuthClient(configuration: config)
```

#### 2. IDトークンの検証

```swift
// トークンを直接検証
let verifiedToken = try await authClient.verifyIDToken(idToken)
print("User ID: \(verifiedToken.uid)")
print("Email: \(verifiedToken.email ?? "none")")

// Authorizationヘッダーから検証（ミドルウェアでの使用）
let authHeader = request.headers["Authorization"].first ?? ""
let verifiedToken = try await authClient.verifyAuthorizationHeader(authHeader)
```

#### 3. 検証済みトークンの情報

```swift
let token = try await authClient.verifyIDToken(idToken)

// 基本情報
token.uid              // Firebase UID
token.email            // メールアドレス（オプション）
token.emailVerified    // メール確認済みフラグ
token.name             // ユーザー名（オプション）
token.picture          // プロフィール画像URL（オプション）
token.phoneNumber      // 電話番号（オプション）

// 認証情報
token.authTime         // 認証時刻
token.issuedAt         // トークン発行時刻
token.expiresAt        // トークン有効期限
token.signInProvider   // サインインプロバイダー（"google.com", "apple.com"等）
```

#### 4. Vaporでのミドルウェア例

```swift
import Vapor
import FirebaseAuthServer

struct FirebaseAuthMiddleware: AsyncMiddleware {
    let authClient: AuthClient

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let authHeader = request.headers["Authorization"].first else {
            throw Abort(.unauthorized, reason: "Missing authorization header")
        }

        do {
            let verifiedToken = try await authClient.verifyAuthorizationHeader(authHeader)
            // ユーザーIDをリクエストに保存
            request.storage[UserIDKey.self] = verifiedToken.uid
            return try await next.respond(to: request)
        } catch let error as AuthError {
            throw Abort(.unauthorized, reason: error.description)
        }
    }
}
```

#### 5. エラーハンドリング

```swift
do {
    let token = try await authClient.verifyIDToken(idToken)
} catch AuthError.tokenMissing {
    // Authorizationヘッダーがない
} catch AuthError.tokenExpired(let expiredAt) {
    // トークンの有効期限切れ
} catch AuthError.tokenInvalid(let reason) {
    // トークン形式が不正
} catch AuthError.signatureInvalid {
    // 署名が不正
} catch AuthError.userNotFound {
    // ユーザーIDが空
}

// エラーコード（Goバックエンド互換）
let errorCode = error.errorCode  // "AUTH_TOKEN_EXPIRED" など
```

#### エラーコード一覧

| エラー | コード | 説明 |
|--------|--------|------|
| `tokenMissing` | `AUTH_TOKEN_MISSING` | Authorizationヘッダーがない |
| `tokenInvalid` | `AUTH_TOKEN_INVALID` | トークン形式が不正 |
| `tokenExpired` | `AUTH_TOKEN_EXPIRED` | トークンの有効期限切れ |
| `verificationFailed` | `AUTH_VERIFICATION_FAILED` | 検証失敗 |
| `userNotFound` | `AUTH_USER_NOT_FOUND` | ユーザーIDが空 |

## 要件

- macOS 14+
- Swift 6.2+
- Xcode 16+

## ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照

## 開発者向け情報

- 🚀 **リリース作業**: [リリースプロセス](RELEASE_PROCESS.md) - 新バージョンをリリースする手順

## サポート

- 📚 [APIリファレンス（DocC）](https://no-problem-dev.github.io/swift-firebase-server/documentation/firestoreserver/)
- 🐛 [Issue報告](https://github.com/no-problem-dev/swift-firebase-server/issues)
- 💬 [ディスカッション](https://github.com/no-problem-dev/swift-firebase-server/discussions)

---

Made with ❤️ by [NOPROBLEM](https://github.com/no-problem-dev)
