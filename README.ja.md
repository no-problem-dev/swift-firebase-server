# swift-firebase-server

サーバーサイド Swift から Firestore・Cloud Storage・Firebase Auth を REST API 経由で直接扱う。Firebase Admin SDK は不要。

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-macOS%2014+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

[English](./README.md) | 日本語

## 特徴

- **型安全なスキーマ DSL** — `@FirestoreSchema`・`@Collection`・`@FirestoreModel` がコレクションパスとモデル型を生成する。`schema.users.document(id).get()` はキャストも文字列パスもなしに `User` で返る
- **CodingKeys を書かない** — `@FirestoreModel` が `snakeCase` 変換、`@Field` によるフィールド単位のキー指定、Firestore に送らないプロパティの `@FieldIgnore` を引き受ける
- **REST ネイティブ** — Admin SDK も C 依存もないので Linux でそのままビルド・実行できる。認証情報は Cloud Run のメタデータサーバー、ローカルの `gcloud` ログイン、エミュレータから自動で解決される
- **宣言的なクエリ** — フィルター・並び替え・ページネーションを Result Builder の `FilterBuilder` で書く
- **ID トークン検証** — Firebase Auth の ID トークンを Google の公開鍵で検証する。鍵は一度取得してキャッシュする
- **Eventarc のペイロード** — Firestore トリガーと Auth ユーザー作成の CloudEvents を Swift の型にデコードする

## クイックスタート

```swift
import FirestoreServer
import FirestoreSchema

@FirestoreModel(keyStrategy: .snakeCase)
struct User {
    let id: String
    let displayName: String
    let email: String
}

@FirestoreSchema
struct Schema {
    @Collection("users", model: User.self)
    enum Users {}
}

// Cloud Run・ローカル gcloud・エミュレータを自分で判別する
let client = try await FirestoreClient(.auto)
let schema = Schema(client: client)

let user = try await schema.users.document("user123").get()

let activeUsers = try await schema.users.execute(
    schema.users.query().filter { Field("status") == "active" }
)
```

## ドキュメント

API リファレンスは DocC カタログから公開している。

- [FirestoreServer](https://no-problem-dev.github.io/swift-firebase-server/documentation/firestoreserver/) — Firestore の REST クライアント・パス・クエリ
- [FirestoreSchema](https://no-problem-dev.github.io/swift-firebase-server/documentation/firestoreschema/) — スキーマとモデルのマクロ
- [FirebaseStorageServer](https://no-problem-dev.github.io/swift-firebase-server/documentation/firebasestorageserver/) — Cloud Storage クライアント
- [FirebaseStorageSchema](https://no-problem-dev.github.io/swift-firebase-server/documentation/firebasestorageschema/) — Storage スキーマのマクロ
- [FirebaseAuthServer](https://no-problem-dev.github.io/swift-firebase-server/documentation/firebaseauthserver/) — ID トークン検証と Admin API
- [EventarcServer](https://no-problem-dev.github.io/swift-firebase-server/documentation/eventarcserver/) — CloudEvents ペイロードのデコード

長めのガイドは [`documentation/`](documentation/README.md) に置いてある。DSL の内部については
[Swift マクロリファレンス](documentation/references/macros/README.md) を参照。

## インストール

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-firebase-server.git", .upToNextMajor(from: "1.0.17"))
]

.target(
    name: "YourApp",
    dependencies: [
        .product(name: "FirestoreServer", package: "swift-firebase-server"),
        .product(name: "FirestoreSchema", package: "swift-firebase-server"),
        .product(name: "FirebaseStorageServer", package: "swift-firebase-server"),
        .product(name: "FirebaseStorageSchema", package: "swift-firebase-server"),
        .product(name: "FirebaseAuthServer", package: "swift-firebase-server"),
    ]
)
```

## 要件

- macOS 14+（Cloud Run など Linux をデプロイ先にできる）
- Swift 6.2+
- Xcode 16+

## 開発に参加する

不具合の報告も Pull Request も歓迎する。ビルド・テスト・リリースの手順は
[CONTRIBUTING.md](CONTRIBUTING.md) を参照。

## ライセンス

MIT License — 詳細は [LICENSE](LICENSE) を参照。
