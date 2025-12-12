# クエリ

FirestoreClientのクエリ機能を使用した条件付き検索です。

## 基本的なクエリ

```swift
let usersRef = client.collection("users")

// クエリを構築して実行
let activeUsers: [User] = try await client.runQuery(
    usersRef.query(as: User.self)
        .whereField("status", isEqualTo: .string("active"))
)

// query メソッドでクロージャ構文も可能
let users: [User] = try await client.query(usersRef, as: User.self) { query in
    query
        .whereField("status", isEqualTo: .string("active"))
        .limit(to: 10)
}
```

## フィルターメソッド

| メソッド | 説明 |
|----------|------|
| `whereField(_:isEqualTo:)` | 等しい |
| `whereField(_:isNotEqualTo:)` | 等しくない |
| `whereField(_:isLessThan:)` | より小さい |
| `whereField(_:isLessThanOrEqualTo:)` | 以下 |
| `whereField(_:isGreaterThan:)` | より大きい |
| `whereField(_:isGreaterThanOrEqualTo:)` | 以上 |
| `whereField(_:arrayContains:)` | 配列に含む |
| `whereField(_:arrayContainsAny:)` | 配列のいずれかを含む |
| `whereField(_:in:)` | 値のいずれか |
| `whereField(_:notIn:)` | 値のいずれでもない |

```swift
let query = usersRef.query(as: User.self)
    .whereField("age", isGreaterThanOrEqualTo: .integer(18))
    .whereField("status", isEqualTo: .string("active"))
```

## ソート

```swift
let users: [User] = try await client.runQuery(
    usersRef.query(as: User.self)
        .order(by: "createdAt", direction: .descending)
)

// 複数フィールドでソート
let users: [User] = try await client.runQuery(
    usersRef.query(as: User.self)
        .order(by: "status")
        .order(by: "createdAt", direction: .descending)
)

// 便利メソッド
let query = usersRef.query(as: User.self)
    .orderAscending(by: "name")
    .orderDescending(by: "score")
```

## 件数制限とオフセット

```swift
let topUsers: [User] = try await client.runQuery(
    usersRef.query(as: User.self)
        .order(by: "score", direction: .descending)
        .limit(to: 10)
)

// オフセット（ページネーション用）
let page2: [User] = try await client.runQuery(
    usersRef.query(as: User.self)
        .order(by: "createdAt")
        .offset(20)
        .limit(to: 20)
)
```

## 複合フィルター

### AND条件

```swift
let results: [User] = try await client.runQuery(
    usersRef.query(as: User.self)
        .whereAnd(
            FieldFilter.isEqualTo("status", .string("active")),
            FieldFilter.isGreaterThanOrEqual("age", .integer(18))
        )
)
```

### OR条件

```swift
let results: [User] = try await client.runQuery(
    usersRef.query(as: User.self)
        .whereOr(
            FieldFilter.isEqualTo("role", .string("admin")),
            FieldFilter.isEqualTo("role", .string("moderator"))
        )
)
```

## カーソルベースページネーション

```swift
// 開始位置を値で指定
let query = usersRef.query(as: User.self)
    .order(by: "createdAt")
    .start(after: .timestamp(lastCreatedAt))
    .limit(to: 20)

// 終了位置を指定
let query = usersRef.query(as: User.self)
    .order(by: "score")
    .end(at: .integer(100))
```

## フィールド選択

```swift
// 特定のフィールドのみ取得
let query = usersRef.query(as: User.self)
    .select("name", "email")
```

## コレクショングループクエリ

```swift
// すべてのサブコレクションを横断してクエリ
let allPosts: [Post] = try await client.runQuery(
    client.collection("posts").query(as: Post.self)
        .collectionGroup()
        .whereField("published", isEqualTo: .boolean(true))
)
```

## 関連ドキュメント

- [FilterBuilder DSL](filter-builder-dsl.md) - より宣言的な構文
- [ドキュメント操作](document-operations.md) - 基本的なCRUD
