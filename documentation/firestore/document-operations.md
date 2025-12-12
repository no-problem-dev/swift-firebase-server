# ドキュメント操作

スキーマベースの型安全なCRUD操作です。

## セットアップ

```swift
import FirestoreServer
import FirestoreSchema

// モデル定義
@FirestoreModel(keyStrategy: .snakeCase)
struct User {
    let id: String
    let displayName: String
    let email: String
}

// スキーマ定義
@FirestoreSchema
struct Schema {
    @Collection("users", model: User.self)
    enum Users {}
}

// クライアントとスキーマの初期化
let client = try await FirestoreClient(.auto)
let schema = Schema(client: client)
```

## 取得（Read）

```swift
// ドキュメント取得（型推論が効く）
let user = try await schema.users.document("user123").get()

// 存在しない場合はFirestoreError.api(.notFound)がスローされる
```

### 存在確認付き取得

```swift
do {
    let user = try await schema.users.document("user123").get()
    // ユーザーが存在する
} catch let error as FirestoreError {
    if case .api(.notFound) = error {
        // ユーザーが存在しない
    } else {
        throw error
    }
}
```

## 作成（Create）

```swift
let newUser = User(id: "user123", displayName: "田中太郎", email: "tanaka@example.com")

// ドキュメント作成（既存の場合はエラー）
try await schema.users.document("user123").create(data: newUser)
```

## 更新（Update）

```swift
let updatedUser = User(id: "user123", displayName: "田中次郎", email: "tanaka@example.com")

// ドキュメント更新（存在しない場合はエラー）
try await schema.users.document("user123").update(data: updatedUser)
```

## 削除（Delete）

```swift
try await schema.users.document("user123").delete()
```

## サブコレクション操作

```swift
@FirestoreSchema
struct Schema {
    @Collection("users", model: User.self)
    enum Users {
        @Collection("posts", model: Post.self)
        enum Posts {}
    }
}

let schema = Schema(client: client)

// サブコレクションのドキュメント取得
let post = try await schema.users.document("user123").posts.document("post456").get()

// サブコレクションにドキュメント作成
try await schema.users.document("user123").posts.document("post456").create(data: newPost)
```

## クエリによる一覧取得

```swift
// 全件取得
let allUsers = try await schema.users.execute(schema.users.query())

// フィルター付き
let activeUsers = try await schema.users.execute(
    schema.users.query()
        .filter { Field("status") == "active" }
        .order(by: "createdAt", direction: .descending)
        .limit(to: 20)
)
```

詳細は [クエリ](queries.md) を参照してください。

## エラーハンドリング

```swift
do {
    let user = try await schema.users.document("user123").get()
} catch let error as FirestoreError {
    switch error {
    case .api(let apiError):
        switch apiError {
        case .notFound:
            print("ドキュメントが見つかりません")
        case .permissionDenied:
            print("権限がありません")
        case .unauthenticated:
            print("認証が必要です")
        default:
            print("APIエラー: \(apiError)")
        }
    case .decoding(let underlying):
        print("デコードエラー: \(underlying)")
    case .encoding(let underlying):
        print("エンコードエラー: \(underlying)")
    }
}
```

## 環境別の初期化

```swift
// Cloud Run / ローカル gcloud（自動検出）
let client = try await FirestoreClient(.auto)

// カスタムデータベースID
let client = try await FirestoreClient(.autoWithDatabase(databaseId: "custom-db"))

// エミュレーター
let client = FirestoreClient(.emulator(projectId: "demo-project"))

// 明示指定（テスト等）
let client = FirestoreClient(.explicit(projectId: "my-project", token: accessToken))
```

## 関連ドキュメント

- [スキーマ定義](schema-definition.md) - `@FirestoreSchema` マクロの詳細
- [クエリ](queries.md) - フィルター、ソート、ページネーション
