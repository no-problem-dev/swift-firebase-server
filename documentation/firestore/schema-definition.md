# Firestore スキーマ定義

`@FirestoreSchema` と `@Collection` マクロを使用して、Firestoreのコレクション構造を型安全に定義します。

## 基本的なスキーマ

```swift
import FirestoreSchema

@FirestoreSchema
struct Schema {
    @Collection("users", model: User.self)
    enum Users {}

    @Collection("products", model: Product.self)
    enum Products {}
}
```

## 生成されるAPI

各 `@Collection` は以下を自動生成します：

| 生成物 | 説明 | 例 |
|--------|------|-----|
| `collectionId` | コレクション名 | `"users"` |
| `collectionPath` | コレクションパス | `"users"` |
| `documentPath(_:)` | ドキュメントパス | `"users/userId"` |
| `Model` | 関連付けられた型 | `User.Type` |

```swift
Schema.Users.collectionId           // "users"
Schema.Users.collectionPath         // "users"
Schema.Users.documentPath("user1")  // "users/user1"
Schema.Users.Model.self             // User.Type
```

## サブコレクション

`@Collection` をネストすることでサブコレクションを定義できます：

```swift
@FirestoreSchema
struct Schema {
    @Collection("users", model: User.self)
    enum Users {
        @Collection("posts", model: Post.self)
        enum Posts {
            @Collection("comments", model: Comment.self)
            enum Comments {}
        }
    }
}
```

サブコレクションは親ドキュメントIDを引数に取ります：

```swift
// 1階層目
Schema.Users.collectionPath                          // "users"
Schema.Users.documentPath("user1")                   // "users/user1"

// 2階層目（親のドキュメントIDが必要）
Schema.Users.Posts.collectionPath("user1")           // "users/user1/posts"
Schema.Users.Posts.documentPath("user1", "post1")    // "users/user1/posts/post1"

// 3階層目（全ての親ドキュメントIDが必要）
Schema.Users.Posts.Comments.collectionPath("user1", "post1")
// → "users/user1/posts/post1/comments"

Schema.Users.Posts.Comments.documentPath("user1", "post1", "comment1")
// → "users/user1/posts/post1/comments/comment1"
```

## model パラメータ

`model:` パラメータには `@FirestoreModel` マクロを適用した型のみ指定できます：

```swift
// OK: @FirestoreModel が適用されている
@FirestoreModel
struct User {
    let id: String
}

@Collection("users", model: User.self)  // ✅ コンパイル成功
enum Users {}

// NG: @FirestoreModel が適用されていない
struct PlainStruct: Codable {
    let id: String
}

@Collection("items", model: PlainStruct.self)  // ❌ コンパイルエラー
enum Items {}
```

この制約により、スキーマで使用される全ての型がFirestoreモデルとして正しく定義されていることが保証されます。

## スキーマの使用例

```swift
// クライアントとスキーマを初期化
let client = try await FirestoreClient(.auto)
let schema = Schema(client: client)

// ドキュメント取得（型推論が効く）
let user = try await schema.users.document("user123").get()

// ドキュメント作成
try await schema.users.document("user123").create(data: newUser)

// サブコレクションの操作
let post = try await schema.users.document("user123").posts.document("post456").get()

// クエリ実行
let recentPosts = try await schema.users.document("user123").posts.execute(
    schema.users.document("user123").posts.query()
        .order(by: "createdAt", direction: .descending)
        .limit(to: 10)
)
```

## 静的パスの使用

スキーマからは静的なパス文字列も取得できます：

```swift
Schema.Users.collectionId           // "users"
Schema.Users.collectionPath         // "users"
Schema.Users.documentPath("user1")  // "users/user1"
```

## 関連ドキュメント

- [モデル定義](model-definition.md) - `@FirestoreModel` マクロの詳細
- [ドキュメント操作](document-operations.md) - CRUD操作
