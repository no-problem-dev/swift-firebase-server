# ファイル操作

StorageClientを使用したファイルのアップロード・ダウンロード操作です。

## クライアントの初期化

```swift
import FirebaseStorageServer

// Cloud Run / ローカル gcloud（自動検出）
let client = try await StorageClient(.auto, bucket: "your-bucket.appspot.com")

// エミュレーター
let client = StorageClient(.emulator(projectId: "demo-project"), bucket: "your-bucket")

// 明示指定
let client = StorageClient(.explicit(projectId: "my-project", token: accessToken), bucket: "your-bucket")
```

## スキーマを使用した操作（推奨）

スキーマを定義すると、型安全かつ簡潔にファイル操作ができます。

### アップロード

```swift
let storage = AppStorage(client: client)
let avatarPath = storage.users.avatar("user123", .jpg)

let object = try await avatarPath.upload(data: imageData)
print("Uploaded: \(object.name)")
```

### ダウンロード

```swift
let data = try await avatarPath.download()
```

### 削除

```swift
try await avatarPath.delete()
```

### メタデータ取得

```swift
let metadata = try await avatarPath.getMetadata()
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
    contentType: "image/jpeg"
)
```

### ダウンロード

```swift
let data = try await client.download(path: "images/photo.jpg")
```

### 削除

```swift
try await client.delete(path: "images/photo.jpg")
```

### 複数ファイルの削除

```swift
let failures = await client.deleteMultiple(paths: ["images/1.jpg", "images/2.jpg", "images/3.jpg"])

for (path, error) in failures {
    print("Failed to delete \(path): \(error)")
}
```

## エラーハンドリング

```swift
do {
    let data = try await client.download(path: path)
} catch let error as StorageError {
    switch error {
    case .notFound:
        // ファイルが見つからない
        print("File not found")
    case .permissionDenied:
        // 権限がない
        print("Permission denied")
    case .unauthenticated:
        // 認証エラー
        print("Unauthenticated")
    case .invalidArgument(let message):
        // 無効な引数
        print(message)
    case .unknown(let statusCode, let message):
        // その他のエラー
        print("Error \(statusCode): \(message)")
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
