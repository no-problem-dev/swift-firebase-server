# ``FirestoreServer``

サーバーサイド Swift 向け Firestore REST API クライアント

## Overview

FirestoreServer は、サーバーサイド Swift アプリケーションから Firestore を操作するための軽量な REST API クライアントです。

主な特徴:
- **REST API ベース**: gRPC 依存なしで動作
- **Swift Concurrency**: async/await によるモダンな非同期処理
- **型安全**: Codable によるシームレスなデータ変換
- **エミュレーター対応**: ローカル開発環境のサポート

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
