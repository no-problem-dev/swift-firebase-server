# 変更履歴

このプロジェクトの全ての重要な変更はこのファイルに記録されます。

フォーマットは [Keep a Changelog](https://keepachangelog.com/ja/1.0.0/) に基づいており、
このプロジェクトは [セマンティックバージョニング](https://semver.org/lang/ja/spec/v2.0.0.html) に準拠しています。

## [未リリース]

なし

## [1.0.7] - 2025-12-12

### 追加
- **@FirestoreModel マクロ** - Firestore モデル定義用マクロを新規追加
  - `keyStrategy: .snakeCase` で camelCase → snake_case 自動変換
  - `@Field("custom_key")` でカスタムフィールド名指定
  - `@FieldIgnore` でエンコード/デコード対象から除外
  - `FirestoreModelProtocol` への自動準拠と `Codable` 適合
  - `CodingKeys` enum の自動生成

- **KeyStrategy** - ランタイムでのキー変換戦略
  - `FirestoreConfiguration` での設定サポート
  - `.snakeCase` / `.useDefault` / `.custom` 変換に対応

- **ドキュメント強化**
  - Swift Macro リファレンス（6ドキュメント）を追加
  - README に「できること」セクションを追加
  - `docs/` → `documentation/` にリネーム（DocC出力と分離）

### 変更
- **@Collection マクロの改善**
  - `model:` パラメータで型関連付けを必須化
  - `typealias Model = T` を自動生成
  - ネスト検出の自動化（`lexicalContext` 使用）
  - 3階層以上のネストに対応

### 削除
- **@SubCollection マクロ** - `@Collection` のネストで代替可能なため廃止

### 破壊的変更
- `@Collection` に `model:` パラメータが必須
- `@SubCollection` マクロを削除（`@Collection` のネストで代替）

## [1.0.6] - 2025-12-11

### 追加
- **GCP 自動認証機能** - サービスアカウント認証の自動管理
  - `AccessTokenProvider` - 環境に応じた認証トークン自動取得
    - Cloud Run: メタデータサーバーから取得
    - ローカル: gcloud CLI 経由で取得
    - エミュレーター: ダミートークンを返す（認証スキップ）
  - `AutoAuthOperations` - 認証トークンを自動取得する Firestore 操作メソッド群
  - `TokenCache` - トークンキャッシュと自動リフレッシュ
  - `MetadataServerClient` - Cloud Run メタデータサーバークライアント
  - `LocalAuthClient` - gcloud CLI 経由のローカル認証クライアント
  - `GCPAuthError` - GCP 認証関連エラー型

- **Firebase Emulator サポート強化**
  - `USE_FIREBASE_EMULATOR=true` または `FIRESTORE_EMULATOR_HOST` 環境変数で自動検出
  - エミュレーターモードでは認証をスキップ（ダミートークン使用）
  - JWT ヘッダーの `kid` フィールドをオプショナル化（エミュレーターは kid なし）
  - 空の署名部分をサポート（エミュレータートークンは署名なし）

### 変更
- **JWTDecoder** - `omittingEmptySubsequences: false` で空の署名部分を保持
- **JWTHeader** - `kid` フィールドをオプショナルに変更
- **IDTokenVerifier** - 本番モードでの `kid` 必須チェックを追加

### 対象モジュール
- FirestoreServer（AutoAuthOperations）
- FirebaseAuthServer（JWT関連）
- Internal（GCPAuth）

## [1.0.5] - 2025-12-10

### 修正
- **Linux 互換性** - ByteBuffer → Data 変換をクロスプラットフォーム対応
  - `NIOFoundationCompat` を使用した `ByteBuffer.toData()` 拡張メソッドを追加
  - macOS専用の `Data(buffer:)` を全箇所で置換（17箇所）
  - Docker (Linux) 環境でのビルド・実行を検証済み
- **Swift 6 マクロ互換性** - Swift 6.2 での警告を解消

### 変更
- **Internal モジュール** - `ByteBufferExtensions.swift` を追加
  - `swift-nio` を明示的な依存関係として追加
  - `NIOFoundationCompat` モジュールをインポート

### 対象モジュール
- FirestoreServer（DocumentOperations, QueryOperations）
- FirebaseStorageServer（StorageClient）
- FirebaseAuthServer（PublicKeyCache）

## [1.0.4] - 2025-12-09

### 変更
- **アクセス修飾子の最適化** - 内部実装の型を `internal` に変更してカプセル化を改善
  - `JWTHeader`, `JWTPayload`, `JWTDecoder`, `DecodedJWT` (FirebaseAuthServer)
  - `FirestoreEncoder`, `FirestoreDecoder`, `FirestoreEncodingError`, `FirestoreDecodingError` (FirestoreServer)
  - `MacroError` (FirestoreMacros), `StorageMacroError` (FirebaseStorageMacros)

### 追加
- **DocC ドキュメント** - 全5モジュールの DocC ドキュメント生成を設定
  - FirestoreServer, FirestoreSchema
  - FirebaseStorageServer, FirebaseStorageSchema
  - FirebaseAuthServer
- GitHub Actions ワークフローを更新し、全ターゲットのドキュメントを生成

### ドキュメント
- README に各モジュールの DocC ドキュメントへの直接リンクを追加

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

[1.0.7]: https://github.com/no-problem-dev/swift-firebase-server/compare/v1.0.6...v1.0.7
[1.0.6]: https://github.com/no-problem-dev/swift-firebase-server/compare/v1.0.5...v1.0.6
[1.0.5]: https://github.com/no-problem-dev/swift-firebase-server/compare/v1.0.4...v1.0.5
[1.0.4]: https://github.com/no-problem-dev/swift-firebase-server/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/no-problem-dev/swift-firebase-server/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/no-problem-dev/swift-firebase-server/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/no-problem-dev/swift-firebase-server/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/no-problem-dev/swift-firebase-server/releases/tag/v1.0.0

<!-- Auto-generated on 2025-12-09T11:13:37Z by release workflow -->

<!-- Auto-generated on 2025-12-09T12:06:18Z by release workflow -->

<!-- Auto-generated on 2025-12-09T12:23:23Z by release workflow -->

<!-- Auto-generated on 2025-12-09T12:59:33Z by release workflow -->

<!-- Auto-generated on 2025-12-09T22:22:46Z by release workflow -->

<!-- Auto-generated on 2025-12-10T21:42:19Z by release workflow -->

<!-- Auto-generated on 2025-12-12T13:39:16Z by release workflow -->
