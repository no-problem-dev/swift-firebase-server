# ``FirebaseStorageSchema``

Cloud Storage スキーマ定義のための Swift マクロ DSL

## Overview

FirebaseStorageSchema は、Swift マクロを使用して Cloud Storage のフォルダ/オブジェクト構造を型安全に定義するための DSL です。

主な特徴:
- **型安全なスキーマ定義**: マクロによるコンパイル時検証
- **自動コード生成**: ボイラープレートコードの削減
- **階層構造対応**: ネストしたフォルダ構造のサポート

## Topics

### Schema Definition

- ``StorageSchema()``
- ``Folder(_:)``
- ``Object(_:extension:)``

### Protocols

- ``StorageSchemaProtocol``
- ``StorageFolderProtocol``
- ``StorageObjectPathProtocol``
