# ``FirestoreSchema``

Firestore スキーマ定義のための Swift マクロ DSL

## Overview

Swift マクロを使用して Firestore のコレクション/ドキュメント構造を型安全に定義する DSL。

主な特徴:
- **型安全なスキーマ定義**: マクロによるコンパイル時検証
- **自動コード生成**: パスアクセサ、CodingKeys の自動生成
- **サブコレクション対応**: `@Collection` のネストでサブコレクションを表現
- **キー変換戦略**: snake_case 変換を自動適用可能

## Topics

### モデル定義

- ``FirestoreModel(keyStrategy:)``
- ``Field(_:)``
- ``Field(strategy:)``
- ``FieldIgnore()``
- ``FirestoreKeyStrategy``

### スキーマ定義

- ``FirestoreSchema()``
- ``Collection(_:model:)``

### プロトコル

- ``FirestoreModelProtocol``
- ``FirestoreSchemaProtocol``
- ``FirestoreCollectionProtocol``
- ``FirestoreDocumentProtocol``
