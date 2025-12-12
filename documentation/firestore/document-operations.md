# ドキュメント操作

FirestoreClientを使用したCRUD操作です。

## クライアントの初期化

```swift
import FirestoreServer

// 本番環境
let client = FirestoreClient(projectId: "your-project-id")

// カスタムデータベースID
let client = FirestoreClient(projectId: "your-project-id", databaseId: "custom-db")

// エミュレーター
let config = FirestoreConfiguration.emulator(projectId: "your-project-id")
let client = FirestoreClient(configuration: config)
```

## 参照の取得

```swift
// コレクション参照
let usersRef = client.collection("users")

// ドキュメント参照（パス直接指定）
let userRef = try client.document("users/user123")

// スキーマを使用（FirestoreSchemaと併用）
let userRef = try client.document(Schema.Users.documentPath("user123"))
let postsRef = client.collection(Schema.Users.Posts.collectionPath("user123"))
```

## 取得（Read）

```swift
// 型指定で取得
let user: User = try await client.getDocument(userRef, as: User.self, authorization: idToken)

// 生のFirestoreDocumentとして取得
let document = try await client.getDocument(userRef, authorization: idToken)
```

## 作成（Create）

```swift
// Encodableオブジェクトを作成
try await client.createDocument(userRef, data: newUser, authorization: idToken)

// フィールドを直接指定
try await client.createDocument(
    userRef,
    fields: [
        "name": .string("田中太郎"),
        "age": .integer(30)
    ],
    authorization: idToken
)
```

## 更新（Update）

```swift
// Encodableオブジェクトで更新
try await client.updateDocument(userRef, data: updatedUser, authorization: idToken)

// フィールドを直接指定
try await client.updateDocument(
    userRef,
    fields: ["displayName": .string("新しい名前")],
    authorization: idToken
)
```

## 削除（Delete）

```swift
try await client.deleteDocument(userRef, authorization: idToken)
```

## 一覧取得

```swift
// 型指定で一覧取得
let (users, nextPageToken) = try await client.listDocuments(
    in: usersRef,
    as: User.self,
    authorization: idToken,
    pageSize: 20
)

// 次のページを取得
if let token = nextPageToken {
    let (moreUsers, _) = try await client.listDocuments(
        in: usersRef,
        as: User.self,
        authorization: idToken,
        pageSize: 20,
        pageToken: token
    )
}
```

## エラーハンドリング

```swift
do {
    let user: User = try await client.getDocument(userRef, as: User.self, authorization: idToken)
} catch let error as FirestoreError {
    switch error {
    case .api(let apiError):
        // APIエラー（notFound, permissionDenied, unauthenticated等）
        print(apiError)
    case .decoding(let underlying):
        // デコードエラー
        print(underlying)
    case .encoding(let underlying):
        // エンコードエラー
        print(underlying)
    }
}
```

## 関連ドキュメント

- [クエリ](queries.md) - 条件付き検索
- [FilterBuilder DSL](filter-builder-dsl.md) - 宣言的フィルター
