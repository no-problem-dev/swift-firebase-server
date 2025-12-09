# 変更履歴

このプロジェクトの全ての重要な変更はこのファイルに記録されます。

フォーマットは [Keep a Changelog](https://keepachangelog.com/ja/1.0.0/) に基づいており、
このプロジェクトは [セマンティックバージョニング](https://semver.org/lang/ja/spec/v2.0.0.html) に準拠しています。

## [1.0.3] - 2025-12-09

### 変更
- **リポジトリ名変更**: `swift-firestore-server` → `swift-firebase-server`
- **パッケージ名変更**: Firebase関連パッケージに統一的な命名規則を適用
  - `StorageServer` → `FirebaseStorageServer`
  - `StorageSchema` → `FirebaseStorageSchema`
  - `StorageMacros` → `FirebaseStorageMacros`
  - `AuthServer` → `FirebaseAuthServer`
- Firestoreパッケージは変更なし（FirestoreServer, FirestoreSchema, FirestoreMacros）

### 移行ガイド
パッケージのインポート文を更新してください：
```swift
// Before
import StorageServer
import StorageSchema
import AuthServer

// After
import FirebaseStorageServer
import FirebaseStorageSchema
import FirebaseAuthServer
```

## [1.0.2] - 2025-12-09

### 追加
- **AuthServer** - Firebase ID トークン検証クライアント
  - `AuthClient` - IDトークン検証のメインエントリポイント
  - `AuthConfiguration` - 本番環境/エミュレーター対応の設定
  - `IDTokenVerifier` - JWT検証とRS256署名検証
  - `PublicKeyCache` - Google公開鍵のキャッシュ（Cache-Control対応）
  - `VerifiedToken` - 検証済みトークン情報（uid, email, signInProvider等）
  - `JWTDecoder` - Base64URLデコードとJSONパース
  - `AuthError` - Goバックエンド互換のエラーコード

### 機能
- Firebase公式ドキュメントに準拠したIDトークン検証
  - JWT形式検証（alg: RS256）
  - クレーム検証（exp, iat, aud, iss, sub, auth_time）
  - RS256署名検証（SwiftCrypto使用）
- `verifyAuthorizationHeader()` - Bearerトークン抽出と検証
- エミュレーターモード - 開発時の署名検証スキップ

### 依存関係
- `swift-crypto` 3.0.0+ を追加（RS256署名検証用）

## [1.0.1] - 2025-12-09

### 追加
- **FilterBuilder DSL** - ResultBuilderベースの宣言的フィルター構文
  - `Field` - フィールド参照と演算子オーバーロード（`==`, `!=`, `<`, `<=`, `>`, `>=`）
  - `And` / `Or` - 明示的な論理グループ化
  - `.contains()`, `.containsAny()`, `.in()`, `.notIn()` - 配列操作
  - `.isNull`, `.isNotNull`, `.isNaN`, `.isNotNaN` - NULL/NaN判定
  - `Query.filter { }` - DSLを使用したフィルター追加
- `FirestoreValueConvertible` - Swift標準型からFirestoreValueへの変換プロトコル

- **StorageServer** - Cloud Storage REST APIクライアント
  - `StorageClient` - アップロード、ダウンロード、削除、メタデータ取得
  - `StorageConfiguration` - 本番環境/エミュレーター対応
  - `StorageObject` - ファイルメタデータモデル
  - `StorageError` - 包括的なエラーハンドリング

- **StorageSchema マクロDSL** - 型安全なストレージスキーマ定義
  - `@StorageSchema` - ルートスキーマ定義マクロ
  - `@Folder("id")` - 階層的フォルダ構造定義
  - `@Object("id")` - ファイルオブジェクトパス定義
  - `FileExtension` - 一般的なファイル形式のContent-Typeマッピング
  - `StorageSchemaProtocol` / `StorageFolderProtocol` / `StorageObjectPathProtocol`

- **Internal（共有モジュール）**
  - `HTTPClientProvider` - 共有HTTPクライアント管理
  - `APIError` - Firebase REST API共通エラー
  - `ServiceConfiguration` プロトコルと `EmulatorConfig`

### 変更
- FirestoreServerをInternalモジュールを使用するようにリファクタリング
- `FirestoreError` が共通エラーケースで `APIError` をラップするように変更

### 削除
- `QueryResult<T>` - 未使用の構造体を削除

## [1.0.0] - 2025-12-09

### 追加
- **FirestoreServer コアライブラリ**
  - `FirestoreClient` - REST APIクライアント
  - `CollectionReference` / `DocumentReference` - 参照型
  - `CollectionPath` / `DocumentPath` / `DatabasePath` - パス型
  - `FirestoreEncoder` / `FirestoreDecoder` - Codable対応
  - `FirestoreValue` - Firestore値型のSwift表現

- **Query API**
  - `Query<T>` - 型安全なクエリビルダー
  - `FieldFilter` - フィールドフィルター（equal, lessThan, greaterThan, in, arrayContains等）
  - `CompositeFilter` - 複合フィルター（AND/OR）
  - `UnaryFilter` - 単項フィルター（isNull, isNotNull）
  - `QueryOrder` - ソート（ascending, descending）
  - ページネーション（limit, offset, startAt, startAfter, endAt, endBefore）

- **FirestoreSchema マクロDSL**
  - `@FirestoreSchema` - ルートスキーマ定義マクロ
  - `@Collection("id")` - コレクション定義マクロ
  - `@SubCollection("id")` - サブコレクション定義マクロ
  - `FirestoreSchemaProtocol` / `FirestoreCollectionProtocol` / `FirestoreDocumentProtocol` - プロトコル定義

### ドキュメント
- 包括的な README.md
- リリースプロセスガイド
- GitHub Actions による DocC 自動デプロイ

[1.0.3]: https://github.com/no-problem-dev/swift-firebase-server/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/no-problem-dev/swift-firebase-server/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/no-problem-dev/swift-firebase-server/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/no-problem-dev/swift-firebase-server/releases/tag/v1.0.0

<!-- Auto-generated on 2025-12-09T11:13:37Z by release workflow -->

<!-- Auto-generated on 2025-12-09T12:06:18Z by release workflow -->
