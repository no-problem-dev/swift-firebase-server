# ``FirestoreSchema``

Firestore スキーマ定義のための Swift マクロ DSL

## Overview

FirestoreSchema は、Swift マクロを使用して Firestore のコレクション/ドキュメント構造を型安全に定義するための DSL です。

主な特徴:
- **型安全なスキーマ定義**: マクロによるコンパイル時検証
- **自動コード生成**: ボイラープレートコードの削減
- **サブコレクション対応**: ネストしたコレクション構造のサポート

## Topics

### Schema Definition

- ``FirestoreSchema()``
- ``Collection(_:)``
- ``SubCollection(_:)``

### Protocols

- ``FirestoreSchemaProtocol``
- ``FirestoreCollectionProtocol``
- ``FirestoreDocumentProtocol``
