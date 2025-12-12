# クエリ

FirestoreClientのクエリ機能を使用した条件付き検索です。

## 基本的なクエリ

```swift
let usersRef = client.collection("users")

let activeUsers: [User] = try await client.runQuery(
    usersRef.query(as: User.self)
        .filter {
            Field("status") == "active"
        }
)
```

## フィルター演算子

### 比較演算子

```swift
.filter {
    Field("age") == 25         // 等しい
    Field("age") != 0          // 等しくない
    Field("age") < 30          // より小さい
    Field("age") <= 30         // 以下
    Field("age") > 18          // より大きい
    Field("age") >= 18         // 以上
}
```

### 配列演算子

```swift
.filter {
    Field("tags").contains("swift")              // 配列に含む
    Field("tags").containsAny(["swift", "go"])   // いずれかを含む
}
```

### IN演算子

```swift
.filter {
    Field("status").in(["active", "pending"])     // いずれかの値
    Field("status").notIn(["deleted", "banned"])  // いずれでもない
}
```

### NULL/NaN チェック

```swift
.filter {
    Field("deletedAt").isNull       // NULLである
    Field("deletedAt").isNotNull    // NULLでない
}
```

## 複合フィルター

### AND条件

```swift
let verifiedAdults: [User] = try await client.runQuery(
    usersRef.query(as: User.self)
        .filter {
            And {
                Field("status") == "active"
                Field("age") >= 18
                Field("verified") == true
            }
        }
)
```

### OR条件

```swift
let admins: [User] = try await client.runQuery(
    usersRef.query(as: User.self)
        .filter {
            Or {
                Field("role") == "admin"
                Field("role") == "moderator"
            }
        }
)
```

### ネストした条件

```swift
let featuredProducts: [Product] = try await client.runQuery(
    productsRef.query(as: Product.self)
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
)
```

## ソート

```swift
let users: [User] = try await client.runQuery(
    usersRef.query(as: User.self)
        .filter { Field("status") == "active" }
        .order(by: "createdAt", direction: .descending)
)

// 複数フィールドでソート
let users: [User] = try await client.runQuery(
    usersRef.query(as: User.self)
        .filter { Field("status") == "active" }
        .order(by: "status")
        .order(by: "createdAt", direction: .descending)
)
```

## 件数制限とオフセット

```swift
let topUsers: [User] = try await client.runQuery(
    usersRef.query(as: User.self)
        .filter { Field("status") == "active" }
        .order(by: "score", direction: .descending)
        .limit(to: 10)
)

// ページネーション
let page2: [User] = try await client.runQuery(
    usersRef.query(as: User.self)
        .filter { Field("status") == "active" }
        .order(by: "createdAt")
        .offset(20)
        .limit(to: 20)
)
```

## カーソルベースページネーション

```swift
let query = usersRef.query(as: User.self)
    .filter { Field("status") == "active" }
    .order(by: "createdAt")
    .start(after: .timestamp(lastCreatedAt))
    .limit(to: 20)
```

## フィールド選択

```swift
let query = usersRef.query(as: User.self)
    .filter { Field("status") == "active" }
    .select("name", "email")
```

## コレクショングループクエリ

```swift
let allPosts: [Post] = try await client.runQuery(
    client.collection("posts").query(as: Post.self)
        .collectionGroup()
        .filter { Field("published") == true }
)
```

## 条件分岐

```swift
func searchUsers(onlyVerified: Bool, minAge: Int?) async throws -> [User] {
    try await client.runQuery(
        usersRef.query(as: User.self)
            .filter {
                And {
                    Field("status") == "active"

                    if onlyVerified {
                        Field("verified") == true
                    }

                    if let minAge = minAge {
                        Field("age") >= minAge
                    }
                }
            }
    )
}
```

## 従来のメソッドチェーン（代替構文）

FilterBuilder DSL の代わりに従来のメソッドチェーンも使用可能です：

```swift
let query = usersRef.query(as: User.self)
    .whereField("status", isEqualTo: .string("active"))
    .whereField("age", isGreaterThanOrEqualTo: .integer(18))
    .order(by: "createdAt", direction: .descending)
    .limit(to: 10)
```

## 関連ドキュメント

- [FilterBuilder DSL](filter-builder-dsl.md) - DSL の詳細リファレンス
- [ドキュメント操作](document-operations.md) - 基本的なCRUD
