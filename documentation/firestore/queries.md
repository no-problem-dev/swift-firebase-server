# クエリ

スキーマベースのクエリ機能です。FilterBuilder DSLによる宣言的な構文を使用します。

## 基本

```swift
// スキーマからクエリを実行
let activeUsers = try await schema.users.execute(
    schema.users.query()
        .filter { Field("status") == "active" }
)
```

## フィルター演算子

| 演算子 | 説明 | 例 |
|--------|------|-----|
| `==` | 等しい | `Field("status") == "active"` |
| `!=` | 等しくない | `Field("status") != "deleted"` |
| `<` | より小さい | `Field("age") < 30` |
| `<=` | 以下 | `Field("age") <= 30` |
| `>` | より大きい | `Field("age") > 18` |
| `>=` | 以上 | `Field("age") >= 18` |
| `.contains()` | 配列に含む | `Field("tags").contains("swift")` |
| `.containsAny()` | いずれかを含む | `Field("tags").containsAny(["swift", "go"])` |
| `.in()` | いずれかの値 | `Field("status").in(["active", "pending"])` |
| `.notIn()` | いずれでもない | `Field("status").notIn(["deleted"])` |
| `.isNull` | NULLである | `Field("deletedAt").isNull` |
| `.isNotNull` | NULLでない | `Field("deletedAt").isNotNull` |

## 複合条件

複数条件は `And` または `Or` で囲みます。

```swift
// AND条件
let results = try await schema.users.execute(
    schema.users.query()
        .filter {
            And {
                Field("status") == "active"
                Field("age") >= 18
            }
        }
)

// OR条件
let admins = try await schema.users.execute(
    schema.users.query()
        .filter {
            Or {
                Field("role") == "admin"
                Field("role") == "moderator"
            }
        }
)

// ネスト
let featured = try await schema.products.execute(
    schema.products.query()
        .filter {
            And {
                Field("active") == true
                Or {
                    Field("category") == "electronics"
                    Field("featured") == true
                }
            }
        }
)
```

## ソート・件数制限

```swift
let results = try await schema.users.execute(
    schema.users.query()
        .filter { Field("status") == "active" }
        .order(by: "createdAt", direction: .descending)
        .limit(to: 20)
)
```

| メソッド | 説明 |
|----------|------|
| `.order(by:direction:)` | ソート（`.ascending` / `.descending`） |
| `.limit(to:)` | 取得件数の上限 |
| `.offset(_:)` | スキップ件数 |
| `.select(_:)` | 取得フィールドを限定 |

## ページネーション

```swift
// オフセットベース
let page2 = try await schema.users.execute(
    schema.users.query()
        .offset(20)
        .limit(to: 20)
)

// カーソルベース
let nextPage = try await schema.users.execute(
    schema.users.query()
        .order(by: "createdAt")
        .start(after: .timestamp(lastCreatedAt))
        .limit(to: 20)
)
```

## 動的フィルター

Swift の制御構文が使えます。

```swift
func search(verified: Bool?, minAge: Int?) async throws -> [User] {
    try await schema.users.execute(
        schema.users.query()
            .filter {
                And {
                    Field("status") == "active"
                    if let verified { Field("verified") == verified }
                    if let minAge { Field("age") >= minAge }
                }
            }
    )
}
```

## サブコレクションのクエリ

```swift
// 特定ユーザーの投稿を取得
let userPosts = try await schema.users.document("user123").posts.execute(
    schema.users.document("user123").posts.query()
        .filter { Field("published") == true }
        .order(by: "createdAt", direction: .descending)
)
```

## 関連ドキュメント

- [ドキュメント操作](document-operations.md) - CRUD操作
- [スキーマ定義](schema-definition.md) - `@FirestoreSchema` マクロの詳細
