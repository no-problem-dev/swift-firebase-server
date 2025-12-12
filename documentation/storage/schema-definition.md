# Storage スキーマ定義

`@StorageSchema`、`@Folder`、`@Object` マクロを使用して、Cloud Storageの構造を型安全に定義します。

## 基本的なスキーマ

```swift
import FirebaseStorageSchema

@StorageSchema
struct AppStorage {
    @Folder("images")
    struct Images {
        @Object("profile")
        struct Profile {}
    }
}
```

## スキーマの使用

```swift
let storage = StorageClient(projectId: "my-project", bucket: "my-bucket.appspot.com")
let schema = AppStorage(client: storage)

// パスの生成
let profilePath = schema.images.profile("user123", .jpg)
// → "images/user123.jpg"
```

## @StorageSchema

スキーマのルートを定義します。`StorageClient` を保持し、子フォルダへのアクセスを提供します。

```swift
@StorageSchema
struct AppStorage {
    @Folder("images")
    struct Images {}
}

// 初期化
let schema = AppStorage(client: storageClient)
```

## @Folder

フォルダ構造を定義します。ネストして階層を表現できます。

```swift
@StorageSchema
struct AppStorage {
    @Folder("images")
    struct Images {
        @Folder("users")
        struct Users {
            @Object("avatar")
            struct Avatar {}
        }

        @Folder("books")
        struct Books {
            @Object("cover")
            struct Cover {}
        }
    }
}
```

### 生成されるパス

```swift
// フォルダアクセス
schema.images                    // Images フォルダ
schema.images.users              // images/users フォルダ
schema.images.books              // images/books フォルダ

// オブジェクトパス
schema.images.users.avatar("user123", .png)
// → "images/users/user123.png"

schema.images.books.cover("book456", .jpg)
// → "images/books/book456.jpg"
```

## @Object

ファイル（オブジェクト）のパターンを定義します。IDと拡張子を指定してパスを生成できます。

```swift
@Folder("documents")
struct Documents {
    @Object("report")
    struct Report {}
}

// 使用例
let path = schema.documents.report("2024-01", .pdf)
// → "documents/2024-01.pdf"
```

## ファイル拡張子

サポートされる拡張子：

| 拡張子 | Content-Type |
|--------|--------------|
| `.jpg` | `image/jpeg` |
| `.jpeg` | `image/jpeg` |
| `.png` | `image/png` |
| `.gif` | `image/gif` |
| `.webp` | `image/webp` |
| `.pdf` | `application/pdf` |
| `.json` | `application/json` |

## 完全な例

```swift
import FirebaseStorageSchema
import FirebaseStorageServer

@StorageSchema
struct AppStorage {
    @Folder("users")
    struct Users {
        @Object("avatar")
        struct Avatar {}

        @Folder("documents")
        struct Documents {
            @Object("file")
            struct File {}
        }
    }

    @Folder("books")
    struct Books {
        @Object("cover")
        struct Cover {}
    }
}

// 使用
let client = StorageClient(projectId: "my-project", bucket: "my-bucket.appspot.com")
let storage = AppStorage(client: client)

// アバター画像のパス
let avatarPath = storage.users.avatar("user123", .png)
// → "users/user123.png"

// ユーザードキュメントのパス
let docPath = storage.users.documents.file("doc456", .pdf)
// → "users/documents/doc456.pdf"

// 書籍カバーのパス
let coverPath = storage.books.cover("isbn-xxx", .jpg)
// → "books/isbn-xxx.jpg"
```

## 関連ドキュメント

- [ファイル操作](file-operations.md) - アップロード/ダウンロード
