# FilterBuilder DSL

ResultBuilderベースの宣言的なフィルター構文です。

## 基本構文

```swift
let activeUsers: [User] = try await client.runQuery(
    usersRef.query(as: User.self)
        .filter {
            Field("status") == "active"
        }
)
```

## 演算子

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
    Field("score").isNaN            // NaNである
    Field("score").isNotNaN         // NaNでない
}
```

## 複合条件

トップレベルでは単一のフィルターのみ許可されます。複数条件は `And` または `Or` で囲む必要があります。

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

## 条件分岐

Swift の `if` 文を使用して動的にフィルターを構築できます：

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

## ループ

```swift
let statuses = ["active", "pending", "review"]

let users: [User] = try await client.runQuery(
    usersRef.query(as: User.self)
        .filter {
            Or {
                for status in statuses {
                    Field("status") == status
                }
            }
        }
)
```

## クエリメソッドとの組み合わせ

```swift
let results: [Product] = try await client.runQuery(
    productsRef.query(as: Product.self)
        .filter {
            And {
                Field("active") == true
                Field("stock") > 0
            }
        }
        .order(by: "price")
        .limit(to: 20)
)
```

## 関連ドキュメント

- [クエリ](queries.md) - 標準的なクエリ構文
- [ドキュメント操作](document-operations.md) - CRUD操作
