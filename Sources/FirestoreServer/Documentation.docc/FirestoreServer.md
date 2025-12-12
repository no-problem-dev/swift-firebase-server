# ``FirestoreServer``

サーバーサイド Swift 向け Firestore REST API クライアント

## Overview

FirestoreServer は、サーバーサイド Swift アプリケーションから Firestore を操作するための軽量な REST API クライアントです。

主な特徴:
- **REST API ベース**: gRPC 依存なしで動作
- **Swift Concurrency**: async/await によるモダンな非同期処理
- **型安全**: Codable によるシームレスなデータ変換
- **自動認証**: Cloud Run / ローカル gcloud の自動検出
- **エミュレーター対応**: ローカル開発環境のサポート

### 初期化

```swift
// Cloud Run / ローカル gcloud 自動検出
let client = try await FirestoreClient(.auto)

// エミュレーター
let client = FirestoreClient(.emulator(projectId: "demo-project"))

// 明示指定
let client = FirestoreClient(.explicit(projectId: "my-project", token: accessToken))
```

## Topics

### Essentials

- ``FirestoreClient``
- ``FirestoreConfiguration``

### References

- ``DocumentReference``
- ``CollectionReference``

### Path Types

- ``DatabasePath``
- ``DocumentPath``
- ``CollectionPath``

### Query

- ``Query``
- ``Field``
- ``SortDirection``

### Filters

- ``FieldFilter``
- ``UnaryFilter``
- ``CompositeFilter``
- ``QueryFilterProtocol``

### Values

- ``FirestoreValue``
- ``FirestoreValueConvertible``
- ``FirestoreDocument``

### Errors

- ``FirestoreError``
- ``PathError``
