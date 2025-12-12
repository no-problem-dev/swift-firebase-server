# Firestore モデル定義

`@FirestoreModel` マクロを使用して、Firestoreドキュメントの構造を定義します。

## 基本的なモデル

```swift
import FirestoreSchema

@FirestoreModel
struct User {
    let id: String
    let name: String
    let email: String
}
```

`@FirestoreModel` は以下を自動生成します：
- `Codable` 準拠
- `Sendable` 準拠
- `FirestoreModelProtocol` 準拠（スキーマでの使用に必要）

## キー変換戦略

### snake_case 変換

Firestoreでは一般的に `snake_case` が使用されます。`keyStrategy: .snakeCase` を指定すると、Swiftの `camelCase` プロパティが自動的に変換されます：

```swift
@FirestoreModel(keyStrategy: .snakeCase)
struct UserProfile {
    let userId: String        // → user_id
    let displayName: String   // → display_name
    let createdAt: Date       // → created_at
}
```

### デフォルト（変換なし）

```swift
@FirestoreModel  // または @FirestoreModel(keyStrategy: .useDefault)
struct Config {
    let apiKey: String     // → apiKey（そのまま）
    let endpoint: String   // → endpoint
}
```

## @Field - カスタムキー名

特定のプロパティに明示的なフィールド名を指定します：

```swift
@FirestoreModel(keyStrategy: .snakeCase)
struct User {
    @Field("uid")
    let userId: String      // → uid（カスタムキーが優先）

    let displayName: String // → display_name（snake_case変換）
}
```

### 個別の変換戦略

プロパティごとに変換戦略を指定することもできます：

```swift
@FirestoreModel  // デフォルトは変換なし
struct MixedModel {
    let normalField: String           // → normalField

    @Field(strategy: .snakeCase)
    let specialField: String          // → special_field
}
```

## @FieldIgnore - フィールド除外

Firestoreに保存しないプロパティを指定します：

```swift
@FirestoreModel(keyStrategy: .snakeCase)
struct CachedDocument {
    let id: String
    let data: String

    @FieldIgnore
    var localTimestamp: Date? = nil  // Firestoreに保存されない

    @FieldIgnore
    var isModified: Bool = false     // ローカル状態の追跡用
}
```

> **注意**: `@FieldIgnore` を適用したプロパティにはデフォルト値が必要です。

## 完全な例

```swift
@FirestoreModel(keyStrategy: .snakeCase)
struct UserProfile {
    // 標準フィールド（snake_case変換）
    let userId: String           // → user_id
    let displayName: String      // → display_name
    let email: String            // → email
    let profileImageId: String?  // → profile_image_id

    // カスタムキー
    @Field("uid")
    let uniqueId: String         // → uid

    // 除外フィールド
    @FieldIgnore
    var localCache: [String: Any]? = nil
}
```

## Firestoreの値型対応

| Swift型 | Firestore値型 |
|---------|---------------|
| `String` | `stringValue` |
| `Int`, `Int64` | `integerValue` |
| `Double`, `Float` | `doubleValue` |
| `Bool` | `booleanValue` |
| `Date` | `timestampValue` |
| `Data` | `bytesValue` |
| `[T]` | `arrayValue` |
| `[String: T]` | `mapValue` |
| `nil` | `nullValue` |

## 関連ドキュメント

- [スキーマ定義](schema-definition.md) - `@Collection` との連携
- [ドキュメント操作](document-operations.md) - モデルを使ったCRUD
