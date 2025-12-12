# ファイル操作

StorageClientを使用したファイルのアップロード・ダウンロード操作です。

## クライアントの初期化

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
    bucket: "your-bucket.appspot.com"
)
let client = StorageClient(configuration: config)
```

## スキーマを使用した操作（推奨）

スキーマを定義すると、型安全かつ簡潔にファイル操作ができます。

### アップロード

```swift
let storage = AppStorage(client: client)
let avatarPath = storage.users.avatar("user123", .jpg)

let object = try await avatarPath.upload(
    data: imageData,
    authorization: idToken
)
print("Uploaded: \(object.name)")
```

### ダウンロード

```swift
let data = try await avatarPath.download(authorization: idToken)
```

### 削除

```swift
try await avatarPath.delete(authorization: idToken)
```

### メタデータ取得

```swift
let metadata = try await avatarPath.getMetadata(authorization: idToken)
print("Size: \(metadata.size) bytes")
print("Content-Type: \(metadata.contentType)")
```

### 公開URL

```swift
let url = avatarPath.publicURL
// → https://storage.googleapis.com/bucket/users/user123.jpg
```

## 直接クライアントを使用した操作

スキーマなしで直接パスを指定する場合：

### アップロード

```swift
let object = try await client.upload(
    data: imageData,
    path: "images/photo.jpg",
    contentType: "image/jpeg",
    authorization: idToken
)
```

### ダウンロード

```swift
let data = try await client.download(
    path: "images/photo.jpg",
    authorization: idToken
)
```

### 削除

```swift
try await client.delete(
    path: "images/photo.jpg",
    authorization: idToken
)
```

### 複数ファイルの削除

```swift
let failures = try await client.deleteMultiple(
    paths: ["images/1.jpg", "images/2.jpg", "images/3.jpg"],
    authorization: idToken
)

for (path, error) in failures {
    print("Failed to delete \(path): \(error)")
}
```

## エラーハンドリング

```swift
do {
    let data = try await client.download(path: path, authorization: token)
} catch let error as StorageError {
    switch error {
    case .api(let apiError):
        // APIエラー（notFound, permissionDenied, unauthenticated等）
        print(apiError)
    case .fileTooLarge(let size, let maxSize):
        // ファイルサイズ超過
        print("Size: \(size), Max: \(maxSize)")
    case .invalidContentType(let contentType):
        // 無効なコンテンツタイプ
        print(contentType)
    case .invalidPath(let path):
        // 無効なパス
        print(path)
    }
}
```

## StorageObject

アップロード・メタデータ取得で返されるオブジェクト情報：

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `name` | `String` | オブジェクト名（パス） |
| `bucket` | `String` | バケット名 |
| `size` | `Int64` | ファイルサイズ（バイト） |
| `contentType` | `String` | Content-Type |
| `timeCreated` | `Date?` | 作成日時 |
| `updated` | `Date?` | 更新日時 |
| `md5Hash` | `String?` | MD5ハッシュ |

## 関連ドキュメント

- [スキーマ定義](schema-definition.md) - @StorageSchema、@Folder、@Object
