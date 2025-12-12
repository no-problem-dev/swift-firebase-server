# ``FirestoreSchema``

Firestore スキーマ定義のための Swift マクロ DSL

## Overview

FirestoreSchema は、Swift マクロを使用して Firestore のコレクション/ドキュメント構造を型安全に定義するための DSL です。

主な特徴:
- **型安全なスキーマ定義**: マクロによるコンパイル時検証
- **自動コード生成**: パスアクセサ、CodingKeys の自動生成
- **サブコレクション対応**: `@Collection` のネストでサブコレクションを表現
- **キー変換戦略**: snake_case 変換を自動適用可能

## Topics

### Model Definition

- ``FirestoreModel(keyStrategy:)``
- ``Field(_:)``
- ``Field(strategy:)``
- ``FieldIgnore()``
- ``FirestoreKeyStrategy``

### Schema Definition

- ``FirestoreSchema()``
- ``Collection(_:model:)``

### Protocols

- ``FirestoreModelProtocol``
- ``FirestoreSchemaProtocol``
- ``FirestoreCollectionProtocol``
- ``FirestoreDocumentProtocol``
